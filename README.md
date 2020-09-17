# SierraHoldingParser

[![Build Status](https://travis-ci.com/NYPL/SierraHoldingParser.svg?branch=main)](https://travis-ci.com/NYPL/SierraHoldingParser) [![GitHub version](https://badge.fury.io/gh/nypl%2FsierraHoldingParser.svg)](https://badge.fury.io/gh/nypl%2FsierraHoldingParser) 

This function takes records from the [SierraUpdatePoller](https://github.com/NYPL/sierraUpdatePollerV2/tree/development) and parses them to extract semantic meaning from the holdings fields and to enhance with data from other sources. The resulting record is validated against an Avro schema and passed to the `HoldingPoster` for persistence in the `Holding` database and passing to the `Holding` Kinesis stream for consumption by other functions.

At the moment two enhancement steps will be taken:

- Location codes are looked up and replaced with an object that contains human-readable labels
- Check-In card/box data is fetched from the Sierra database and incorporated with the corresponding holding record

## Requirements

- ruby 2.7
- AWS CLI

## Dependencies

- nypl_ruby_util@0.0.2
- rspec@3.9.0
- mocha@1.11.2

## Environment Variables

- SCHEMA_TYPE: Avro schema to encode parser messages with
- KINESIS_STREAM: Destination stream for parsed messages
- LOG_LEVEL: Standard logging level. Defaults to INFO
- PLATFORM_API_BASE_URL: URL for the NYPL API, used to fetch Avro schema
- LOCATIONS_JSONLD_URL: URL for JSONLD document representing current mapping of location codes to full location objects

## Installation

This function is developed using the AWS SAM framework, [which has installation instructions here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

To install the dependencies for this function, they must be bundled for this framework and should be done with `rake run_bundler`

## Usage

To run the function locally it may be invoked with rake, where EVENT is the name of the specific event in the `events` directory that you would like to invoke the function with:

`rake run_local[FUNCTION]`

## Testing

Testing is provided via `rspec` with `mocha` for stubbing/mocking. The test suite can be invoked with `rake test`
