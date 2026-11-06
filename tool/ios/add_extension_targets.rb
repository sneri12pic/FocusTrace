#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the FocusTrace Screen Time extension targets to ios/Runner.xcodeproj.
#
# Lets the Xcode project be edited from Windows/Linux, where Xcode is not
# available. Idempotent: re-running it on an up-to-date project leaves
# project.pbxproj byte-for-byte unchanged. Existing targets are found by name and
# their build settings re-applied; missing pieces are created.
#
# Usage (from the repository root):
#   gem install xcodeproj      # once
#   ruby tool/ios/add_extension_targets.rb
#
# What it manages (see docs/ios/ios-port-architecture.md):
#   * project-wide IPHONEOS_DEPLOYMENT_TARGET = 16.0
#   * Runner: entitlements file, its own Swift sources (RUNNER_SOURCES),
#     FocusTraceKit sources, system frameworks, extension dependencies and
#     embed phases (placed before "Thin Binary")
#   * FocusTraceMonitor / FocusTraceShield / FocusTraceShieldAction /
#     FocusTraceReport extension targets with Info.plist, entitlements,
#     FocusTraceKit sources and system frameworks
#
# Flutter's xcconfigs (Flutter/Debug.xcconfig, Flutter/Release.xcconfig) stay on
# Runner only. Extensions use Config/Extension.xcconfig, which includes only
# Flutter's Generated.xcconfig for version numbers, and never link Flutter.

require 'fileutils'
require 'xcodeproj'

REPO_ROOT = File.expand_path('../..', __dir__)
IOS_DIR = File.join(REPO_ROOT, 'ios')
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

DEPLOYMENT_TARGET = '16.0'
SWIFT_VERSION = '5.0'
APP_BUNDLE_ID = 'com.stepandemianenko.focustrace'
APP_GROUP = 'group.com.stepandemianenko.focustrace'
KIT_DIR = 'FocusTraceKit'
EXTENSION_XCCONFIG = 'Config/Extension.xcconfig'
CONFIGURATIONS = %w[Debug Release Profile].freeze

APP_EXTENSION_TYPE = 'com.apple.product-type.app-extension'
EXTENSIONKIT_TYPE = 'com.apple.product-type.extensionkit-extension'

# Runner links these so later phases can call FamilyControls / ManagedSettings /
# DeviceActivity from the method channels without further project edits.
RUNNER_FRAMEWORKS = %w[FamilyControls ManagedSettings DeviceActivity SwiftUI UserNotifications].freeze

# Runner's own Swift files besides AppDelegate.swift (which Flutter created).
RUNNER_SOURCES = %w[FocusTraceChannels.swift ActivityPicker.swift SelectionIconsView.swift].freeze

# Every target compiles all of FocusTraceKit, so every extension also links
# FamilyControls, ManagedSettings and DeviceActivity.

EXTENSIONS = [
  {
    name: 'FocusTraceMonitor',
    bundle_suffix: 'monitor',
    display_name: 'FocusTrace Monitor',
    product_type: APP_EXTENSION_TYPE,
    extension_point: 'com.apple.deviceactivity.monitor-extension',
    principal_class: 'DeviceActivityMonitorExtension',
    sources: %w[DeviceActivityMonitorExtension.swift],
    frameworks: %w[DeviceActivity ManagedSettings FamilyControls UserNotifications]
  },
  {
    name: 'FocusTraceShield',
    bundle_suffix: 'shield',
    display_name: 'FocusTrace Shield',
    product_type: APP_EXTENSION_TYPE,
    extension_point: 'com.apple.ManagedSettingsUI.shield-configuration-service',
    principal_class: 'ShieldConfigurationExtension',
    sources: %w[ShieldConfigurationExtension.swift],
    frameworks: %w[ManagedSettings ManagedSettingsUI FamilyControls DeviceActivity]
  },
  {
    name: 'FocusTraceShieldAction',
    bundle_suffix: 'shieldaction',
    display_name: 'FocusTrace Shield Action',
    product_type: APP_EXTENSION_TYPE,
    extension_point: 'com.apple.ManagedSettings.shield-action-service',
    principal_class: 'ShieldActionExtension',
    sources: %w[ShieldActionExtension.swift],
    frameworks: %w[ManagedSettings FamilyControls DeviceActivity UserNotifications]
  },
  {
    # DeviceActivityReport extensions are ExtensionKit extensions (as in Xcode's
    # own template): @main DeviceActivityReportExtension, extension point declared
    # under EXAppExtensionAttributes, embedded into $(EXTENSIONS_FOLDER_PATH).
    name: 'FocusTraceReport',
    bundle_suffix: 'report',
    display_name: 'FocusTrace Report',
    product_type: EXTENSIONKIT_TYPE,
    extension_point: 'com.apple.deviceactivityui.report-extension',
    principal_class: nil,
    sources: %w[FocusTraceReportExtension.swift],
    frameworks: %w[DeviceActivity SwiftUI FamilyControls ManagedSettings]
  }
].freeze

# ---------------------------------------------------------------------------
# File templates (written only when missing, so hand edits survive re-runs)
# ---------------------------------------------------------------------------

def plist_header
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
  XML
end

def entitlements_xml
  plist_header + <<~XML
    <dict>
    \t<key>com.apple.developer.family-controls</key>
    \t<true/>
    \t<key>com.apple.security.application-groups</key>
    \t<array>
    \t\t<string>#{APP_GROUP}</string>
    \t</array>
    </dict>
    </plist>
  XML
end

def extension_info_plist_xml(ext)
  extension_block =
    if ext[:product_type] == EXTENSIONKIT_TYPE
      <<~XML
        \t<key>EXAppExtensionAttributes</key>
        \t<dict>
        \t\t<key>EXExtensionPointIdentifier</key>
        \t\t<string>#{ext[:extension_point]}</string>
        \t</dict>
      XML
    else
      <<~XML
        \t<key>NSExtension</key>
        \t<dict>
        \t\t<key>NSExtensionPointIdentifier</key>
        \t\t<string>#{ext[:extension_point]}</string>
        \t\t<key>NSExtensionPrincipalClass</key>
        \t\t<string>$(PRODUCT_MODULE_NAME).#{ext[:principal_class]}</string>
        \t</dict>
      XML
    end

  plist_header + <<~XML + extension_block + "</dict>\n</plist>\n"
    <dict>
    \t<key>CFBundleDevelopmentRegion</key>
    \t<string>$(DEVELOPMENT_LANGUAGE)</string>
    \t<key>CFBundleDisplayName</key>
    \t<string>#{ext[:display_name]}</string>
    \t<key>CFBundleExecutable</key>
    \t<string>$(EXECUTABLE_NAME)</string>
    \t<key>CFBundleIdentifier</key>
    \t<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    \t<key>CFBundleInfoDictionaryVersion</key>
    \t<string>6.0</string>
    \t<key>CFBundleName</key>
    \t<string>$(PRODUCT_NAME)</string>
    \t<key>CFBundlePackageType</key>
    \t<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    \t<key>CFBundleShortVersionString</key>
    \t<string>$(FLUTTER_BUILD_NAME)</string>
    \t<key>CFBundleVersion</key>
    \t<string>$(FLUTTER_BUILD_NUMBER)</string>
  XML
end

def write_if_missing(relative_path, content)
  path = File.join(IOS_DIR, relative_path)
  return if File.exist?(path)

  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
  puts "  wrote ios/#{relative_path}"
end

# ---------------------------------------------------------------------------
# Project helpers
# ---------------------------------------------------------------------------

def find_or_create_group(project, name)
  project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == name } ||
    project.main_group.new_group(name, name)
end

def find_or_create_file(group, path)
  group.files.find { |f| f.path == path } || group.new_reference(path)
end

def ensure_build_file(phase, file_ref)
  return if phase.files_references.include?(file_ref)

  phase.add_file_reference(file_ref, true)
end

def frameworks_group(project)
  project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == 'Frameworks' } ||
    project.main_group.new_group('Frameworks')
end

def system_framework_ref(project, name)
  group = frameworks_group(project)
  path = "System/Library/Frameworks/#{name}.framework"
  group.files.find { |f| f.path == path } ||
    group.new_reference(path, :sdk_root).tap do |ref|
      ref.name = "#{name}.framework"
      ref.last_known_file_type = 'wrapper.framework'
    end
end

def ensure_frameworks(project, target, names)
  names.each { |name| ensure_build_file(target.frameworks_build_phase, system_framework_ref(project, name)) }
end

def ensure_configurations(target)
  list = target.build_configuration_list
  CONFIGURATIONS.each do |config_name|
    next if list[config_name]

    config = target.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    config.name = config_name
    config.build_settings = {}
    list.build_configurations << config
  end
end

def extension_build_settings(ext, config_name)
  debug = config_name == 'Debug'
  {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => "#{ext[:name]}/#{ext[:name]}.entitlements",
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEBUG_INFORMATION_FORMAT' => debug ? 'dwarf' : 'dwarf-with-dsym',
    'ENABLE_BITCODE' => 'NO',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => "#{ext[:name]}/Info.plist",
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks'
    ],
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{APP_BUNDLE_ID}.#{ext[:bundle_suffix]}",
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SDKROOT' => 'iphoneos',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => debug ? 'DEBUG' : '',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_OPTIMIZATION_LEVEL' => debug ? '-Onone' : '-O',
    'SWIFT_VERSION' => SWIFT_VERSION,
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'VALIDATE_PRODUCT' => debug ? 'NO' : 'YES'
  }
end

def find_or_create_extension_target(project, ext)
  target = project.native_targets.find { |t| t.name == ext[:name] }
  return target if target

  puts "  adding target #{ext[:name]}"
  target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
  project.targets << target
  target.name = ext[:name]
  target.product_name = ext[:name]
  target.product_type = ext[:product_type]
  target.build_configuration_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
  target.build_configuration_list.default_configuration_is_visible = '0'
  target.build_configuration_list.default_configuration_name = 'Release'

  product = project.products_group.new_reference("#{ext[:name]}.appex", :built_products)
  product.include_in_index = '0'
  product.set_explicit_file_type('wrapper.app-extension')
  product.last_known_file_type = nil
  target.product_reference = product

  target.build_phases << project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
  target.build_phases << project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
  target.build_phases << project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
  target
end

def configure_extension(project, ext, kit_refs, extension_xcconfig_ref)
  write_if_missing("#{ext[:name]}/Info.plist", extension_info_plist_xml(ext))
  write_if_missing("#{ext[:name]}/#{ext[:name]}.entitlements", entitlements_xml)

  target = find_or_create_extension_target(project, ext)
  target.product_type = ext[:product_type]
  ensure_configurations(target)
  target.build_configuration_list.build_configurations.each do |config|
    config.base_configuration_reference = extension_xcconfig_ref
    config.build_settings = extension_build_settings(ext, config.name)
  end

  group = find_or_create_group(project, ext[:name])
  ext[:sources].each do |source|
    ensure_build_file(target.source_build_phase, find_or_create_file(group, source))
  end
  find_or_create_file(group, 'Info.plist')
  find_or_create_file(group, "#{ext[:name]}.entitlements")
  kit_refs.each { |ref| ensure_build_file(target.source_build_phase, ref) }
  ensure_frameworks(project, target, ext[:frameworks])
  target
end

# Embed phases must come before Flutter's "Thin Binary" script phase, otherwise
# Xcode reports a dependency cycle in the Runner target.
def ensure_embed_phase(runner, name, subfolder_spec, dst_path)
  phase = runner.copy_files_build_phases.find { |p| p.name == name }
  unless phase
    phase = runner.project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    phase.name = name
    runner.build_phases << phase
  end
  phase.symbol_dst_subfolder_spec = subfolder_spec
  phase.dst_path = dst_path

  thin_binary = runner.shell_script_build_phases.find { |p| p.name == 'Thin Binary' }
  if thin_binary
    runner.build_phases.delete(phase)
    runner.build_phases.insert(runner.build_phases.index(thin_binary), phase)
  end
  phase
end

def embed_extension(runner, phase, extension_target)
  product = extension_target.product_reference
  unless phase.files_references.include?(product)
    build_file = phase.add_file_reference(product, true)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
  return if runner.dependencies.any? { |d| d.target == extension_target }

  runner.add_dependency(extension_target)
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.native_targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')
puts "Updating #{PROJECT_PATH}"

# Project-wide deployment target (Runner inherits it; Flutter's xcconfigs do not
# set one).
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
end

# Shared FocusTraceKit sources: one file reference per file, compiled into
# every target (no framework target).
kit_group = find_or_create_group(project, KIT_DIR)
kit_files = Dir.children(File.join(IOS_DIR, KIT_DIR)).select { |f| f.end_with?('.swift') }.sort
kit_refs = kit_files.map { |f| find_or_create_file(kit_group, f) }

config_group = find_or_create_group(project, 'Config')
extension_xcconfig_ref = find_or_create_file(config_group, File.basename(EXTENSION_XCCONFIG))

# Runner.
write_if_missing('Runner/Runner.entitlements', entitlements_xml)
runner_group = project.main_group.children.find { |c| c.display_name == 'Runner' }
find_or_create_file(runner_group, 'Runner.entitlements')
runner.build_configuration_list.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
RUNNER_SOURCES.each do |source|
  ensure_build_file(runner.source_build_phase, find_or_create_file(runner_group, source))
end
kit_refs.each { |ref| ensure_build_file(runner.source_build_phase, ref) }
ensure_frameworks(project, runner, RUNNER_FRAMEWORKS)

# Extensions.
app_extension_phase = nil
extensionkit_phase = nil
EXTENSIONS.each do |ext|
  target = configure_extension(project, ext, kit_refs, extension_xcconfig_ref)
  if ext[:product_type] == EXTENSIONKIT_TYPE
    extensionkit_phase ||= ensure_embed_phase(runner, 'Embed ExtensionKit Extensions', :products_directory,
                                              '$(EXTENSIONS_FOLDER_PATH)')
    embed_extension(runner, extensionkit_phase, target)
  else
    app_extension_phase ||= ensure_embed_phase(runner, 'Embed Foundation Extensions', :plug_ins, '')
    embed_extension(runner, app_extension_phase, target)
  end
end

# Keep the extension groups and Config next to Runner in the navigator, sorted.
project.main_group.children.sort_by! do |child|
  order = %w[Flutter Config FocusTraceKit Runner] + EXTENSIONS.map { |e| e[:name] } +
          %w[RunnerTests Frameworks Products]
  [order.index(child.display_name) || order.size, child.display_name.to_s]
end

project.save
puts 'Done.'
