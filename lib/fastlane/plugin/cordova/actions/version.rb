module Fastlane
  module Actions
    class VersionAction < Action
      def self.run(params)
        version_and_build_number =
          Fastlane::Actions::UpdateVersionAndBuildNumberAction.run(
            platform: params[:platform],
            pathToConfigXML: params[:pathToConfigXML],
            skip_version: params[:skip_version]
          )

        Fastlane::Actions::BumpVersionAction.run(
          message:
            "fastlane(#{
              params[:platform].to_s == 'ios' ? 'ios' : 'android'
            }): build #{version_and_build_number[:build_number]}, version: #{
              version_and_build_number[:version]
            }"
        )

        Fastlane::Actions::PushToGitRemoteAction.run(
          remote: params[:remote],
          local_branch: params[:local_branch],
          remote_branch: params[:remote_branch],
          force: params[:force],
          tags: params[:tags]
        )

        return version_and_build_number
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

        # Below a few examples
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
            description: 'Path to the Cordova config.xml',
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
            key: :local_branch,
            env_name: 'FL_GIT_PUSH_LOCAL_BRANCH',
            description:
              'The local branch to push from. Defaults to the current branch',
            default_value_dynamic: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :remote_branch,
            env_name: 'FL_GIT_PUSH_REMOTE_BRANCH',
            description:
              'The remote branch to push to. Defaults to the local branch',
            default_value_dynamic: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :force,
            env_name: 'FL_PUSH_GIT_FORCE',
            description: 'Force push to remote',
            is_string: false,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :tags,
            env_name: 'FL_PUSH_GIT_TAGS',
            description: 'Whether tags are pushed to remote',
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :remote,
            env_name: 'FL_GIT_PUSH_REMOTE',
            description: 'The remote to push to',
            default_value: 'origin'
          ),
          FastlaneCore::ConfigItem.new(
            key: :skip_version,
            env_name: 'SKIP_VERSION',
            description: 'CI flag to skip updating the version',
            optional: true,
            default_value: false,
            type: Boolean
          )
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        %w[garygrossgarten]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
