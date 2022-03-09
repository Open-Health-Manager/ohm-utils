# Ohm::Utils

Utilities for MITRE's Open Health Manager™, including
- generate a transaction bundle (create all) from a directory of files with json FHIR resources
- generate a [Patient Data Receipt](https://open-health-manager.github.io/patient-data-receipt-ig/) from a directory of files with json FHIR resources

## Usage

Run using the interactive ruby prompt: `irb -r ./lib/ohm/utils.rb`

### Prerequisites

To use these bundle generation utilities, you must
- have a collection of FHIR resources, one per file
- all stored in the same directory

### Transaction Bundle

To create a transaction bundle (create each entry new) from a directory, use the following command:
```sh
puts Ohm::Utils::createTransactionFromDirectory("[target directory]")
```

This will output the filename where the resulting bundle will be stored, which will be 
- in the parent directory of the target
- with name "[target directory short name]_transactionBundle.json"

### Patient Data Receipt Message Bundle

To create a Patient Data Receipt message bundle from a directory, use the following command:
```sh
puts Ohm::Utils::createPDRFromDirectory("[target directory]", "[username]", "[sourceURL]")
```

This will output the filename where the resulting bundle will be stored, which will be 
- in the parent directory of the target
- with name "[target directory short name]_PDRMessageBundle.json"

## Example

This repository has some sample resource files that you can use to generate example bundles. To generate files resources_PDRMessageBundle.json and resources_transactionBundle.json, use the following commands
```sh
cd /path/to/ohm-utils
irb -r ./lib/ohm/utils.rb
```

Within the ruby interpreter, execute
```rb
puts Ohm::Utils::createPDRFromDirectory("example/resources", "a
394Kutch271", "http://example.org")
puts Ohm::Utils::createTransactionFromDirectory("example/resour
ces")
```

## License
Copyright 2022 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.