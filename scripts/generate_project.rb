#!/usr/bin/env ruby
require 'fileutils'
require 'xcodeproj'

project_root = File.expand_path('..', __dir__)
project_path = File.join(project_root, 'TemplateApp.xcodeproj')
FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '1500'

target = project.new_target(:application, 'TemplateApp', :ios, '17.0', nil, :swift)
target.product_name = 'TemplateApp'

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.learnandbecurious.template'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['INFOPLIST_FILE'] = 'TemplateApp/TemplateApp/Info.plist'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
end

sources_group = project.main_group.new_group('TemplateApp')
sources_group.set_path(nil)

config_group = sources_group.new_group('Config')
config_group.set_path(nil)

auth_group = sources_group.new_group('Auth')
auth_group.set_path(nil)

api_group = sources_group.new_group('API')
api_group.set_path(nil)

sidebar_group = sources_group.new_group('Sidebar')
sidebar_group.set_path(nil)

preview_group = project.main_group.new_group('Preview Content')
preview_group.set_path(nil)

base_paths = {
  sources_group => 'TemplateApp/TemplateApp',
  config_group => 'TemplateApp/TemplateApp/Config',
  auth_group => 'TemplateApp/TemplateApp/Auth',
  api_group => 'TemplateApp/TemplateApp/API',
  sidebar_group => 'TemplateApp/TemplateApp/Sidebar'
}

source_files = {
  sources_group => [
    ['TemplateAppApp.swift', 'TemplateAppApp.swift'],
    ['ContentView.swift', 'ContentView.swift']
  ],
  config_group => [
    ['AppManifest.swift', 'AppManifest.swift'],
    ['ManifestLoader.swift', 'ManifestLoader.swift'],
    ['Color+Hex.swift', 'Color+Hex.swift'],
    ['app.json', 'app.json']
  ],
  auth_group => [
    ['LoginView.swift', 'LoginView.swift'],
    ['AuthSession.swift', 'AuthSession.swift'],
    ['AuthSessionStorage.swift', 'AuthSessionStorage.swift'],
    ['AccountView.swift', 'AccountView.swift'],
    ['HostedUILoginController.swift', 'HostedUILoginController.swift']
  ],
  api_group => [
    ['APIClient.swift', 'APIClient.swift']
  ],
  sidebar_group => [
    ['RootContainerView.swift', 'RootContainerView.swift'],
    ['SidebarItem.swift', 'SidebarItem.swift'],
    ['SidebarView.swift', 'SidebarView.swift']
  ]
}

source_files.each do |group, files|
  base = base_paths[group]
  files.each do |relative_name, display_name|
    file_ref = group.new_file(display_name)
    file_ref.set_path(File.join(base, relative_name))
    file_ref.set_source_tree('SOURCE_ROOT')
    if display_name == 'app.json'
      target.add_resources([file_ref])
    else
      target.add_file_references([file_ref])
    end
  end
end

assets_ref = sources_group.new_file('Assets.xcassets')
assets_ref.set_path('TemplateApp/TemplateApp/Assets.xcassets')
assets_ref.set_source_tree('SOURCE_ROOT')

info_ref = sources_group.new_file('Info.plist')
info_ref.set_path('TemplateApp/TemplateApp/Info.plist')
info_ref.set_source_tree('SOURCE_ROOT')

strings_ref = sources_group.new_file('Localization/Base.lproj/Localizable.strings')
strings_ref.set_path('TemplateApp/TemplateApp/Localization/Base.lproj/Localizable.strings')
strings_ref.set_source_tree('SOURCE_ROOT')

preview_ref = preview_group.new_file('Preview Assets.xcassets')
preview_ref.set_path('TemplateApp/TemplateApp/Preview Content/Preview Assets.xcassets')
preview_ref.set_source_tree('SOURCE_ROOT')

target.add_resources([assets_ref, strings_ref, preview_ref])

framework_ref = project.frameworks_group.new_file('System/Library/Frameworks/AuthenticationServices.framework')
target.frameworks_build_phase.add_file_reference(framework_ref)

project.save
