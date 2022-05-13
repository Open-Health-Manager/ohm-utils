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
    
    ########################################
    # JSON files into a directory to bundles
    # - transaction bundle
    # - PDR message bundle
    ########################################

    def self.createTransactionFromDirectory(directory, useResourceId = false)
      
      # create the bundle
      bundle = FHIR::Bundle.new(
        'type' => 'transaction'
      )

      # loop over files in the directory
      Dir.foreach(directory) do |filename|
        next if not(filename.end_with?(".json"))
        filepath = File.join(directory, filename)
        next if File.directory?(filepath)

        puts "processing file: " + filename

        # parse json and add as a bundle entry
        contents = File.read(filepath)
        resource = FHIR.from_contents(contents)
        bundle.entry << createTransactionBundleEntry(resource, useResourceId)

      end

      # write to a file
      dirname = File.basename(directory)
      bundleFile = File.join(File.join(directory, ".."), dirname + "_transactionBundle.json")
      File.write(bundleFile, bundle.to_json)

      puts ""
      puts "Bundle written to: " + bundleFile
      puts ""

      return bundleFile

    end

    def self.createTransactionBundleEntry(resource, useResourceId = false)
      
      resourceType = resource.class.name.split('::').last


      if (useResourceId)
        
        if (resource.id == "")
          raise "Failed to use resource Id: empty"
        end
        method = 'PUT'
        url = resourceType + "/" + resource.id

      else
        method = 'POST'
        url = resourceType
      end

      entry = FHIR::Bundle::Entry.new(
        'resource' => resource,
        'request' => {
          'method' => method,
          'url' => url
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
        next if not(filename.end_with?(".json"))
        filepath = File.join(directory, filename)
        next if File.directory?(filepath)

        puts "processing file: " + filename
        
        # parse json and add as a bundle entry
        contents = File.read(filepath)
        resource = FHIR.from_contents(contents)
        bundle.entry << createPDRBundleEntry(resource)
      end

      # write to a file
      dirname = File.basename(directory)
      bundleFile = File.join(File.join(directory, ".."), dirname + "_PDRMessageBundle.json")
      File.write(bundleFile, bundle.to_json)

      puts ""
      puts "Bundle written to: " + bundleFile
      puts ""

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


    ########################################
    # SearchSet bundle to PDR Bundle
    ########################################

    def self.searchSetToPDR(searchSetBundle, username, sourceURL)
      # create the bundle
      pdrBundle = FHIR::Bundle.new(
        'type' => 'message'
      )

      # add the message header
      pdrBundle.entry << createPDRMessageHeaderEntry(username, sourceURL)
      searchSetBundle.entry.each do |searchSetEntry|
        pdrBundle.entry << createPDRBundleEntry(searchSetEntry.resource)
      end

      return pdrBundle
    end

    ########################################
    # unwrap bundles into individual files (requires ids)
    ########################################

    def self.bundleToIndividualResourceFiles(filepath)
      
      contents = File.read(filepath)
      bundle = FHIR.from_contents(contents)

      directory_name = File.join(File.dirname(filepath), File.basename(filepath, ".*"))
      Dir.mkdir(directory_name) unless File.exists?(directory_name)

      if not(bundle.is_a?(FHIR::Bundle))
        raise "Can't convert to individual resource files: not a bundle"
      end

      bundle.entry.each do |entry|
        # sometimes nil shows up here for some reason
        next unless entry
  
        if not(entry.resource.id)
          raise "Can't convert to individual resource files: entry missing an id"
        end
        
        resource = entry.resource
        fileName = resource.resourceType + "-" + resource.id + ".json"
        resourceFile = File.join(directory_name, fileName)
        File.write(resourceFile, resource.to_json)

        puts "wrote resource file: " + resourceFile

      end

    end

    def self.bundlesInDirToIndividualResourceFiles(directory)
      Dir.foreach(directory) do |filename|
        next if not(filename.end_with?(".json"))
        filepath = File.join(directory, filename)
        next if File.directory?(filepath)

        puts "processing file: " + filename
        
        bundleToIndividualResourceFiles(filepath)
      end
    end

    ########################################
    # - convert JSON resource files in directory 
    # and sub-directories into FSH
    # - collect resulting FSH files
    ########################################

    
    def self.executeGoFSH(directory)
      outDir = File.join(directory, "goFSH")
      cmd = "gofsh -s single-file -o """ + outDir + """ """ + directory + """"
      wasGood = system( cmd )
      puts "processing directory: " + directory + "; result = " + (wasGood ? "success" : "fail")
    end

    def self.subDirsExecuteGoFSH(directory) 
      Dir.foreach(directory) do |filename|
        next if (filename == ".")
        next if (filename == "..")
        filepath = File.join(directory, filename)
        next if not(File.directory?(filepath))

        executeGoFSH(filepath)
      end
    end

    def self.subDirsCollectFSHFiles(directory) 
      targetDir = File.join(directory, "asFSH")
      Dir.mkdir(targetDir) unless File.exists?(targetDir)
      
      Dir.foreach(directory) do |filename|
        next if (filename == ".")
        next if (filename == "..")
        next if (filename == "asFSH")
        filepath = File.join(directory, filename)
        next if not(File.directory?(filepath))

        sourceFile = File.join(File.join(File.join(File.join(File.join(directory, filename), "goFSH"), "input"), "fsh"), "resources.fsh")
        cmd = "cp " + sourceFile + " " + targetDir
        puts(cmd)
        system ( cmd )
      end
    end
  end
end
