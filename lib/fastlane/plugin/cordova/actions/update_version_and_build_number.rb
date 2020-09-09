require 'fastlane/action'
require_relative '../helper/cordova_helper'
require_relative './update_version'
require_relative './increment_build_number'

module Fastlane
  module Actions
    module SharedValues
      APP_BUILD_NUMBER = :APP_BUILD_NUMBER
      APP_BUILD_VERSION = :APP_BUILD_VERSION
    end

    class UpdateVersionAndBuildNumberAction < Action
      def self.run(params)
        version = ''
        build_number = ''
        if (params[:skip_version])
          puts('skipping version, just incrementing build number')
          old_version =
            sh "echo \"cat //*[local-name()='widget']/@version\" | xmllint --shell #{
                 params[:pathToConfigXML]
               }|  awk -F'[=\"]' '!/>/{print $(NF-1)}'"
          version = old_version.delete!("\n")
        else
          version =
            Fastlane::Actions::UpdateVersionAction.run(
              pathToConfigXML: params[:pathToConfigXML],
              auto_increment: params[:auto_increment]
            )
        end
        build_number =
          Fastlane::Actions::IncrementNumberAction.run(
            pathToConfigXML: params[:pathToConfigXML],
            platform: params[:platform]
          )

        ENV['APP_BUILD_NUMBER'] = version.to_s
        ENV['APP_BUILD_VERSION'] = build_number.to_s

        return { version: version, build_number: build_number }
      end

      def self.description
        'Fastlane plugin for Cordova Projects'
      end

      def self.authors
        %w[Fivethree]
      end

      def self.output
        [
          ['APP_BUILD_NUMBER', 'App build number'],
          ['APP_BUILD_VERSION', 'App build version']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        'returns object containing version and build_number'
      end

      def self.details
        # Optional:
        'Fastlane'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :platform,
            env_name: 'CORDOVA_PLATFORM',
            description: 'Platform. Should be either android or ios',
            is_string: true,
            default_value: '',
            verify_block:
              proc do |value|
                unless ['', 'android', 'ios'].include? value
                  UI.user_error!('Platform should be either android or ios')
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :pathToConfigXML,
            env_name: 'INCREMENT_BUILD_CONFIG',
            description: '---',
            optional: false,
            verify_block:
              proc do |value|
                unless File.exist?(value)
                  UI.user_error!(
                    'Couldnt find config.xml! Please change your path.'
                  )
                end
              end,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :auto_increment,
            env_name: 'AUTO_INCREMENT',
            description: 'Auto increment app version',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :skip_version,
            env_name: 'SKIP_VERSION',
            description: '---',
            optional: true,
            default_value: false,
            type: Boolean
          )
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
