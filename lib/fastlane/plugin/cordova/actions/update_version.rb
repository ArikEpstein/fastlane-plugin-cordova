module Fastlane
  module Actions
    class UpdateVersionAction < Action
      def self.run(params)
        if (params[:auto_increment])
          puts 'take the version from project package.json'
          version = sh "npx -c 'echo $npm_package_version'"
          # version = sh "npx -c 'echo \"$npm_package_version\"'"
          version = version.delete!("\n")
        else
          old_version =
            sh "echo \"cat //*[local-name()='widget']/@version\" | xmllint --shell #{
                 params[:pathToConfigXML]
               }|  awk -F'[=\"]' '!/>/{print $(NF-1)}'"
          old_version = old_version.delete!("\n")
          puts "current version: #{old_version}"

          puts "Insert new version number, current version in config.xml is '#{
                 old_version
               }' (Leave empty and press enter to skip this step): "
          new_version_number = STDIN.gets.strip
          puts "new version: #{new_version_number}"

          if new_version_number.length > 0
            puts 'take new version number'
            version = new_version_number
          else
            puts 'take old version number'
            version = old_version
          end
        end

        text = File.read(params[:pathToConfigXML])

        new_contents = text.gsub(/version="[0-9.]*"/, "version=\"#{version}\"")

        File.open(params[:pathToConfigXML], 'w') do |file|
          file.puts new_contents
        end

        return version
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'A short description with <= 80 characters of what this action does'
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        'You can use this action to do cool things...'
      end

      def self.available_options
        # Define all options your action supports.

        [
          FastlaneCore::ConfigItem.new(
            key: :auto_increment,
            env_name: 'AUTO_INCREMENT',
            description: 'Auto increment app version',
            optional: true,
            default_value: true,
            type: Boolean
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
          )
        ]
      end

      def self.return_value
        'returns the new version specified in config.xml'
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ['Your GitHub/Twitter Name']
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        platform == :ios
      end
    end
  end
end
