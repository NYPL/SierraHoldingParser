require 'aws-sdk-lambda'
require 'aws-sdk-cloudwatchevents'
require 'yaml'

class RakeHelper

  attr_reader(
    :travis_branch,
    :aws_access_key_id,
    :aws_secret_access_key,
    :aws_configuration,
    :lambda_client,
    :yaml,
    :lambda_config,
    :function_name,
    :event
  )

  def initialize
    @travis_branch = ENV["TRAVIS_BRANCH"].upcase
    @travis_branch = ['MAIN', 'MASTER'].include? @travis_branch ? 'PRODUCTION' : @travis_branch
    @aws_access_key_id = ENV["AWS_ACCESS_KEY_ID_#{travis_branch}"]
    @aws_secret_access_key = ENV["AWS_SECRET_ACCESS_KEY_#{travis_branch}"]
    @yaml = YAML.safe_load(File.read('.travis.yml'))
    p 'using configuration: ', aws_configuration
    if configured?
      @lambda_client = Aws::Lambda::Client.new(aws_configuration)
      @lambda_config = yaml["deploy"].find {|conf| conf["function_name"].include? travis_branch.downcase}
      region = @lambda_config["region"]
      @aws_configuration = aws_configuration = {
        region: region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      }
    end
  end

  def configured?
    access_key_id && secret_access_key && region
  end


  def update_lambda_configuration
    unless configured? && lambda_config
      p 'insufficient configuration'
      return nil
    end


    vpc_config = lambda_config["vpc"]
    environment_variables = lambda_config["environment_variables"]&.map {|str| str.split "="}.to_h
    layers = lambda_config["layers"]
    updated_lambda_configuration = [
      :vpc_config,
      :environment_variables,
      :layers
    ]
      .select {|key| lambda_config[key]}
      .map {|key| [key, lambda_config[key]]}
      .to_h
    p 'updating_function_configuration with: ', updated_lambda_configuration
    update_configuration_resp = lambda_client.update_function_configuration(updated_lambda_configuration)
    p 'update_configuration_resp: ', update_configuration_resp
  end

  def update_event
    unless lambda_config["events"]
      p 'no event config'
      return nil
    end

    @event = lambda_config["event"]
    if event["event_source_arn"]
      add_event_source
    elsif event["SCHEDULE_EXPRESSION"]
      add_cron
    end
  end

  def add_event_source
    existing_events = lambda_client.list_event_source_mappings({function_name: function_name}).event_source_mappings
    arn = event["event_source_arn"]
    if !existing_events.any? { |existing_event| existing_event.event_source_arn == arn }
      event_to_create = event.map {|k,v| [k.to_sym, v]}.to_h
      event_to_create[:function_name] = function_name
      p 'creating event: ', event_to_create
      create_resp = lambda_client.create_event_source_mapping(event_to_create)
      p 'created: ', create_resp
    end
    existing_events.each do |existing_event|
      if existing_event.event_source_arn != arn
        p 'deleting event with uuid: ', existing_event.uuid, 'and arn: ', existing_event.event_source_arn
        lambda_client.delete_event_source_mapping({uuid: existing_event.uuid})
      end
    end
  end

  def add_cron
    events_client = Aws::CloudWatchEvents::Client.new(configuration)
    schedule_expression = event["schedule_expression"]
    rule_name = "#{function_name}-rule"
    p 'rule_name: ', rule_name, 'schedule_expression: ', schedule_expression
    events_client.put_rule(name: rule_name, schedule_expression: schedule_expression)
    return p 'missing function_name' unless function_name
    target_id = "#{function_name}-lambda"
    p 'getting lambda with function name', function_name, 'target_id', target_id
    lambda_resp = lambda_client.get_function(function_name: function_name).configuration
    arn = lambda_resp.function_arn
    begin
      policy_resp = lambda_client.get_policy(function_name: function_name)
      unless policy_resp.policy.include?("#{function_name}-permission")
        permission = lambda_client.add_permission({
          function_name: function_name,
          principal: 'events.amazonaws.com',
          statement_id: "#{function_name}-permission",
          action: 'lambda:InvokeFunction'
          })
          p 'permission: ', permission
        else
          p 'lambda already has permission'
        end
    rescue Aws::Lambda::Errors::ResourceNotFoundException
      p 'no policy'
    end
    p 'putting targets ', 'rule: ', rule_name, 'target_id: ', target_id, "arn: ", arn
    events_client.put_targets(rule: rule_name, targets: [{id: target_id, arn: arn}])
  end

end
