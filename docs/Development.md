## Running Locally

To test your local changes:

1. Create a local `./configuration.yaml` file with a configuration that runs your new changes. Do not check this file in.
1. Run `ruby ./app/version_checker.rb ./configuration.yaml`.
1. Use CTRL+C to stop running the program.

## Error Handling

When doing a version check for a platform a failure to get the current version or the unique identifier of a device is considered fatal, while a failure to gather any other information is non-fatal.

If a failure occurs trying to get the current version or unique identifer then the platform should raise a `CurrentVersionCheckError` by calling `raise_current_version_check_error("failure message")`. Often the failure message here will be `exception.message` from another exception that occurred.

If there is a failure gathering any other piece of information then an appropriate error message should be printed to the console using `puts` and the MQTT payload should be generated with the information that was successfully fetched (such as the current version).