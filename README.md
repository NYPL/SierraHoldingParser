# SierraHoldingParser

[![Build Status](https://travis-ci.com/NYPL/SierraHoldingParser.svg?branch=main)](https://travis-ci.com/NYPL/SierraHoldingParser) [![GitHub version](https://badge.fury.io/gh/nypl%2FsierraHoldingParser.svg)](https://badge.fury.io/gh/nypl%2FsierraHoldingParser) 

This function takes records from the [SierraUpdatePoller](https://github.com/NYPL/sierraUpdatePollerV2/tree/development) and parses them to extract semantic meaning from the holdings fields and to enhance with data from other sources. The resulting record is validated against an Avro schema and passed to the `HoldingPoster` for persistence in the `Holding` database and passing to the `Holding` Kinesis stream for consumption by other functions.

At the moment two enhancement steps will be taken:

- Location codes are looked up and replaced with an object that contains human-readable labels
- Check-In card/box data is fetched from the Sierra database and incorporated with the corresponding holding record

## Requirements

- ruby 3.3
- AWS CLI

## Dependencies

- nypl_ruby_util@0.0.2
- rspec@3.9.0
- mocha@1.11.2

## Environment Variables

- IN_SCHEMA_TYPE: Avro schema to encode incoming events
- OUT_SCHEMA_TYPE: Avro schema to encode outgoing messages
- KINESIS_STREAM: Destination stream for parsed messages
- LOG_LEVEL: Standard logging level. Defaults to INFO
- PLATFORM_API_BASE_URL: URL for the NYPL API, used to fetch Avro schema
- LOCATIONS_JSONLD_URL: URL for JSONLD document representing current mapping of location codes to full location objects

## Installation

This function is developed using the AWS SAM framework, [which has installation instructions here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

To install the dependencies for this function, they must be bundled for this framework:

```
rake run_bundler
```

## Usage

To run the function locally it may be invoked with rake, where EVENT is the name of the specific event in the `events` directory that you would like to invoke the function with, e.g.:

```
rake 'run_local[./events/test-holding.json]'
```

Note that a sam-cli/Docker issue ( https://github.com/aws/aws-sam-cli/issues/3118 ) still appears to be breaking AWS auth when invoked via sam-cli due to sam-cli injecting an empty `AWS_SESSION_TOKEN` var into the container, confusing all AWS calls. This is patched in the short term by simply removing the var during `init` when it's found and empty. Because we only run `init` at startup, this should not impact deployed code.

It's possible this issue may be resolved in a future update to [the sam-cli](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html). As of at least 1.132.0, the bug appears to remain.

## Testing

Testing is provided via `rspec` with `mocha` for stubbing/mocking. The test suite can be invoked with `bundle exec rspec`
