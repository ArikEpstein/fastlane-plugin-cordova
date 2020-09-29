module Fastlane
  module Actions
    module SharedValues
      CORDOVA_IOS_RELEASE_BUILD_PATH = :CORDOVA_IOS_RELEASE_BUILD_PATH
      CORDOVA_ANDROID_RELEASE_BUILD_PATH = :CORDOVA_ANDROID_RELEASE_BUILD_PATH
    end

    class CordovaAction < Action
      # valid action params

      ANDROID_ARGS_MAP = {
        keystore_path: 'keystore',
        keystore_password: 'storePassword',
        key_password: 'password',
        keystore_alias: 'alias',
        bundle: 'bundle',
        min_sdk_version: 'gradleArg=-PcdvMinSdkVersion',
        cordova_no_fetch: 'cordovaNoFetch',
        verbose: 'verbose'
      }

      IOS_ARGS_MAP = {
        type: 'packageType',
        team_id: 'developmentTeam',
        provisioning_profile: 'provisioningProfile',
        build_flag: 'buildFlag'
      }

      # extract arguments only valid for the platform from all arguments
      # + map action params to the cli param they will be used for
      def self.get_platform_args(params, platform_args_map)
        platform_args = []
        platform_args_map.each do |action_key, cli_param|
          param_value = params[action_key]

          # handle `build_flag` being an Array
          if action_key.to_s == 'build_flag' && param_value.kind_of?(Array)
            unless param_value.empty?
              param_value.each do |flag|
                platform_args << "--#{cli_param}=#{flag.shellescape}"
              end
            end
            # handle all other cases
          else
            unless param_value.to_s.empty?
              platform_args <<
                "--#{cli_param}=#{Shellwords.escape(param_value)}"
            end
          end
        end

        return platform_args.join(' ')
      end

      def self.get_android_args(params)
        if params[:key_password].empty?
          params[:key_password] = params[:keystore_password]
        end

        return self.get_platform_args(params, ANDROID_ARGS_MAP)
      end

      def self.get_ios_args(params)
        app_identifier =
          CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)

        if params[:provisioning_profile].empty?
          # If `match` or `sigh` were used before this, use the certificates returned from there
          params[:provisioning_profile] =
            ENV['SIGH_UUID'] ||
              ENV["sigh_#{app_identifier}_#{params[:type].sub('-', '')}"]
        end

        params[:type] = 'ad-hoc' if params[:type] == 'adhoc'
        params[:type] = 'app-store' if params[:type] == 'appstore'

        return self.get_platform_args(params, IOS_ARGS_MAP)
      end

      # add platform if missing (run step #1)
      def self.check_platform(params)
        platform = params[:platform]
        if platform && !File.directory?("./platforms/#{platform}")
          if params[:cordova_no_fetch]
            sh "cordova platform add #{platform} --no-telemetry --nofetch"
          else
            sh "cordova platform add #{platform} --no-telemetry"
          end
        end
      end

      # app_name
      def self.get_app_name
        config = REXML::Document.new(File.open('config.xml'))
        return config.elements['widget'].elements['name'].first.value
      end

      # actual building! (run step #2)
      def self.build(params)
        args = [params[:release] ? '--release' : '--debug']
        args << '--device' if params[:device]
        args << '--prod' if params[:prod]
        args << '--bundle' if params[:bundle]
        args << '--browserify' if params[:browserify]
        args << '--verbose' if params[:verbose]

        if !params[:cordova_build_config_file].to_s.empty?
          args <<
            "--buildConfig=#{
              Shellwords.escape(params[:cordova_build_config_file])
            }"
        end

        if params[:platform].to_s == 'android'
          android_args = self.get_android_args(params)
        end
        ios_args = self.get_ios_args(params) if params[:platform].to_s == 'ios'

        if params[:cordova_prepare]
          sh "npx --no-install cordova prepare #{
               params[:platform]
             } --no-telemetry #{args.join(' ')}"
        end

        if params[:platform].to_s == 'ios'
          sh "npx --no-install cordova compile #{
               params[:platform]
             } --no-telemetry #{args.join(' ')} -- #{ios_args}"
        elsif params[:platform].to_s == 'android'
          sh "npx --no-install cordova compile #{
               params[:platform]
             } --no-telemetry #{args.join(' ')} -- -- #{android_args}"
        end
      end

      # export build paths (run step #3)
      def self.set_build_paths(is_release)
        app_name = self.get_app_name
        build_type = is_release ? 'release' : 'debug'
        apk_name = is_release ? 'app-release' : 'app-debug'

        ENV['CORDOVA_ANDROID_RELEASE_BUILD_PATH'] =
          "./platforms/android/app/build/outputs/apk/#{build_type}/#{
            apk_name
          }.apk"

        ENV['CORDOVA_IOS_RELEASE_BUILD_PATH'] =
          "./platforms/ios/build/device/#{app_name}.ipa"

        # TODO: https://github.com/bamlab/fastlane-plugin-cordova/issues/7
      end

      def self.run(params)
        # if params[:fresh]
        # Fastlane::Actions::CleanInstallAction.run(params)
        #  end
        self.check_platform(params)
        self.build(params)
        self.set_build_paths(params[:release])
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Build your Cordova app'
      end

      def self.details
        'Easily integrate your cordova build into a Fastlane setup'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :platform,
            env_name: 'CORDOVA_PLATFORM',
            description:
              'Platform to build on. Should be either android or ios',
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
            key: :release,
            env_name: 'CORDOVA_RELEASE',
            description: 'Build for release if true, or for debug if false',
            is_string: false,
            default_value: true,
            verify_block:
              proc do |value|
                unless [false, true].include? value
                  UI.user_error!('Release should be boolean')
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :device,
            env_name: 'CORDOVA_DEVICE',
            description: 'Build for device',
            is_string: false,
            default_value: true,
            verify_block:
              proc do |value|
                unless [false, true].include? value
                  UI.user_error!('Device should be boolean')
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :prod,
            env_name: 'CORDOVA_PROD',
            description: 'Build for production',
            is_string: false,
            optional: true,
            default_value: false,
            verify_block:
              proc do |value|
                unless [false, true].include? value
                  UI.user_error!('Prod should be boolean')
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :type,
            env_name: 'CORDOVA_IOS_PACKAGE_TYPE',
            description:
              'This will determine what type of build is generated by Xcode. Valid options are development, enterprise, adhoc, and appstore',
            is_string: true,
            default_value: 'appstore',
            verify_block:
              proc do |value|
                unless %w[
                         development
                         enterprise
                         adhoc
                         appstore
                         ad-hoc
                         app-store
                       ].include? value
                  UI.user_error!(
                    'Valid options are development, enterprise, adhoc, and appstore.'
                  )
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :team_id,
            env_name: 'CORDOVA_IOS_TEAM_ID',
            description:
              'The development team (Team ID) to use for code signing',
            is_string: true,
            default_value:
              CredentialsManager::AppfileConfig.try_fetch_value(:team_id)
          ),
          FastlaneCore::ConfigItem.new(
            key: :provisioning_profile,
            env_name: 'CORDOVA_IOS_PROVISIONING_PROFILE',
            description:
              'GUID of the provisioning profile to be used for signing',
            is_string: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :bundle,
            env_name: 'CORDOVA_ANDROID_BUNDLE',
            description: 'Use bundle for android',
            is_string: false,
            optional: true,
            default_value: false,
            verify_block:
              proc do |value|
                unless [false, true].include? value
                  UI.user_error!('Bundle should be boolean')
                end
              end
          ),
          FastlaneCore::ConfigItem.new(
            key: :keystore_path,
            env_name: 'CORDOVA_ANDROID_KEYSTORE_PATH',
            description: 'Path to the Keystore for Android',
            is_string: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :keystore_password,
            env_name: 'CORDOVA_ANDROID_KEYSTORE_PASSWORD',
            description: 'Android Keystore password',
            is_string: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :key_password,
            env_name: 'CORDOVA_ANDROID_KEY_PASSWORD',
            description: 'Android Key password (default is keystore password)',
            is_string: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :keystore_alias,
            env_name: 'CORDOVA_ANDROID_KEYSTORE_ALIAS',
            description: 'Android Keystore alias',
            is_string: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :browserify,
            env_name: 'CORDOVA_BROWSERIFY',
            description: 'Specifies whether to browserify build or not',
            default_value: false,
            optional: true,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :cordova_prepare,
            env_name: 'CORDOVA_PREPARE',
            description:
              'Specifies whether to run `npx cordova prepare` before building',
            default_value: true,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :fresh,
            env_name: 'BUILD_FRESH',
            description: 'Clean install packages, plugins and platform',
            default_value: false,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :plugins,
            env_name: 'REFRESH_PLUGINS',
            description: 'also refresh plugins',
            default_value: false,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :min_sdk_version,
            env_name: 'CORDOVA_ANDROID_MIN_SDK_VERSION',
            description:
              'Overrides the value of minSdkVersion set in AndroidManifest.xml',
            default_value: '',
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :cordova_no_fetch,
            env_name: 'CORDOVA_NO_FETCH',
            description:
              'Call `npx cordova platform add` with `--nofetch` parameter',
            default_value: true,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_flag,
            env_name: 'CORDOVA_IOS_BUILD_FLAG',
            description:
              'An array of Xcode buildFlag. Will be appended on compile command',
            is_string: false,
            optional: true,
            default_value: []
          ),
          FastlaneCore::ConfigItem.new(
            key: :cordova_build_config_file,
            env_name: 'CORDOVA_BUILD_CONFIG_FILE',
            description:
              'Call `npx cordova compile` with `--buildConfig=<ConfigFile>` to specify build config file path',
            is_string: true,
            optional: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :verbose,
            env_name: 'CORDOVA_VERBOSE',
            description: 'Pipe out more verbose output to the shell',
            optional: true,
            default_value: false,
            is_string: false,
            verify_block:
              proc do |value|
                unless [false, true].include? value
                  UI.user_error!('Verbose should be boolean')
                end
              end
          )
        ]
      end

      def self.output
        [
          [
            'CORDOVA_ANDROID_RELEASE_BUILD_PATH',
            'Path to the signed release APK if it was generated'
          ],
          [
            'CORDOVA_IOS_RELEASE_BUILD_PATH',
            'Path to the signed release IPA if it was generated'
          ]
        ]
      end

      def self.authors
        %w[almouro]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          "cordova(
            platform: 'ios'
          )",
          "cordova(
            platform: 'android',
            keystore_path: './staging.keystore',
            keystore_alias: 'alias_name',
            keystore_password: 'store_password'
          )"
        ]
      end

      def self.category
        :building
      end
    end
  end
end
