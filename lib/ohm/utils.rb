# Copyright 2022 The MITRE Corporation
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# frozen_string_literal: true

require "fhir_models"

module Ohm
  module Utils
    class Error < StandardError; end
    
    def self.createTransactionFromDirectory(directory)
      
      # create the bundle
      bundle = FHIR::Bundle.new(
        'type' => 'transaction'
      )

      # loop over files in the directory
      Dir.foreach(directory) do |filename|
        filepath = File.join(directory, filename)
        next if File.directory?(filepath)
        
        # parse json and add as a bundle entry
        contents = File.read(filepath)
        resource = FHIR.from_contents(contents)
        bundle.entry << createTransactionBundleEntry(resource)


      end

      # write to a file
      dirname = File.basename(directory)
      bundleFile = File.join(File.join(directory, ".."), dirname + "_transactionBundle.json")
      File.write(bundleFile, bundle.to_json)

      return bundleFile

    end

    def self.createTransactionBundleEntry(resource)
      
      resourceType = resource.class.name.split('::').last

      entry = FHIR::Bundle::Entry.new(
        'resource' => resource,
        'request' => {
          'method' => 'POST',
          'url' => resourceType
        }
      )

      # need to setup fullUrl to help with references
      # separate cases for UUIDs
      if (isUUID(resource.id))
        entry.fullUrl = "urn:uuid:" + resource.id
      elsif not(resource.id.empty?)
        entry.fullUrl = resourceType + "/" + resource.id
      end
      
      return entry
      
    end

    def self.createPDRFromDirectory(directory, username, sourceURL)
      
      # create the bundle
      bundle = FHIR::Bundle.new(
        'type' => 'message'
      )

      # add the message header
      bundle.entry << createPDRMessageHeaderEntry(username, sourceURL)

      # add each file as an entry to the bundle
      Dir.foreach(directory) do |filename|
        filepath = File.join(directory, filename)
        next if File.directory?(filepath)
        
        # parse json and add as a bundle entry
        contents = File.read(filepath)
        resource = FHIR.from_contents(contents)
        bundle.entry << createPDRBundleEntry(resource)
      end

      # write to a file
      dirname = File.basename(directory)
      bundleFile = File.join(File.join(directory, ".."), dirname + "_PDRMessageBundle.json")
      File.write(bundleFile, bundle.to_json)

      return bundleFile

    end

    def self.createPDRBundleEntry(resource)
      FHIR::Bundle::Entry.new(
        'resource' => resource
      )
    end

    def self.createPDRMessageHeaderEntry(username, sourceURL)
      FHIR::Bundle::Entry.new(
        'resource' => FHIR::MessageHeader.new(
          'eventUri' => 'urn:mitre:healthmanager:pdr',
          'source' => {
            'endpoint' => sourceURL
          },
          'extension' => [
        	  {
              'url' => 'https://github.com/Open-Health-Manager/patient-data-receipt-ig/StructureDefinition/AccountExtension',
              'valueString': username
            }
          ]
        )
      )
    end

    def self.isUUID(uuid)
      uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      return uuid_regex.match?(uuid.to_s.downcase)
    end

  end
    
end
