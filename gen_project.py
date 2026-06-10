#!/usr/bin/env python3
"""Generates Serenity.xcodeproj/project.pbxproj

DEPRECATED / OUT OF DATE — do not run.
The real project.pbxproj has since diverged: different bundle id and signing
team, an Info.plist reference, a SerenityTests target, and removed
microphone/speech permission keys. Running this script would overwrite all of
that (and its output paths point to another machine). Kept for history only.
"""
import uuid, os, re

def uid():
    return uuid.uuid4().hex[:24].upper()

# File IDs
IDS = {}
def fid(name):
    if name not in IDS:
        IDS[name] = uid()
    return IDS[name]

# Swift source files
SWIFT = [
    "SerenityApp.swift",
    "Models.swift",
    "AppViewModel.swift",
    "KeychainHelper.swift",
    "PersistenceStore.swift",
    "NotificationScheduler.swift",
    "LLMClient.swift",
    "Components.swift",
    "ContentView.swift",
    "OnboardingView.swift",
    "HomeView.swift",
    "CheckInView.swift",
    "ExerciseViews.swift",
    "JournalViews.swift",
    "ProgramViews.swift",
    "AnalyticsViews.swift",
    "MoodCalendarView.swift",
    "WellnessViews.swift",
    "PsychologistChatView.swift",
]

# Resource files
RESOURCES = [
    "Assets.xcassets",
]

# Localization
LPROJ = ["en", "ru"]

# Assign IDs
APP_ID       = uid()  # PBXNativeTarget
PROJ_ID      = uid()  # PBXProject
MAIN_GROUP   = uid()
PROD_GROUP   = uid()
SRC_GROUP    = uid()
APP_REF      = uid()  # .app product
SRC_PHASE    = uid()
FW_PHASE     = uid()
RES_PHASE    = uid()
PROJ_CFG_LIST= uid()
TGT_CFG_LIST = uid()
DBG_PROJ     = uid()
REL_PROJ     = uid()
DBG_TGT      = uid()
REL_TGT      = uid()
ASSETS_REF   = uid()
ASSETS_BUILD = uid()
EN_REF       = uid()
RU_REF       = uid()
STRINGS_VAR  = uid()  # variant group for Localizable.strings
EN_STRINGS   = uid()
RU_STRINGS   = uid()
ENTITLE_REF  = uid()
ENTITLE_BLD  = uid()

# Per-file IDs
for f in SWIFT:
    fid(f + "_ref")
    fid(f + "_build")

pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXBuildFile section */
"""

for f in SWIFT:
    pbxproj += f'\t\t{fid(f+"_build")} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid(f+"_ref")} /* {f} */; }};\n'

pbxproj += f'\t\t{ASSETS_BUILD} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS_REF} /* Assets.xcassets */; }};\n'
pbxproj += f'\t\t{EN_STRINGS} /* en */ = {{isa = PBXBuildFile; fileRef = {EN_REF} /* en */; }};\n'
pbxproj += f'\t\t{RU_STRINGS} /* ru */ = {{isa = PBXBuildFile; fileRef = {RU_REF} /* ru */; }};\n'

pbxproj += """/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""

for f in SWIFT:
    pbxproj += f'\t\t{fid(f+"_ref")} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};\n'

pbxproj += f'\t\t{APP_REF} /* Serenity.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Serenity.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
pbxproj += f'\t\t{ASSETS_REF} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};\n'
pbxproj += f'\t\t{EN_REF} /* en */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/Localizable.strings; sourceTree = "<group>"; }};\n'
pbxproj += f'\t\t{RU_REF} /* ru */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = ru; path = ru.lproj/Localizable.strings; sourceTree = "<group>"; }};\n'
pbxproj += f'\t\t{ENTITLE_REF} /* Serenity.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Serenity.entitlements; sourceTree = "<group>"; }};\n'

pbxproj += """/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
"""
pbxproj += f'\t\t{FW_PHASE} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'

pbxproj += """/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
"""
pbxproj += f'\t\t{MAIN_GROUP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{SRC_GROUP} /* Serenity */,\n\t\t\t\t{PROD_GROUP} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

src_children = "\n".join([f'\t\t\t\t{fid(f+"_ref")} /* {f} */,' for f in SWIFT])
pbxproj += f'\t\t{SRC_GROUP} /* Serenity */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{src_children}\n\t\t\t\t{ASSETS_REF} /* Assets.xcassets */,\n\t\t\t\t{STRINGS_VAR} /* Localizable.strings */,\n\t\t\t\t{ENTITLE_REF} /* Serenity.entitlements */,\n\t\t\t);\n\t\t\tpath = Serenity;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

pbxproj += f'\t\t{PROD_GROUP} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{APP_REF} /* Serenity.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'
pbxproj += f'\t\t{STRINGS_VAR} /* Localizable.strings */ = {{\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n\t\t\t\t{EN_REF} /* en */,\n\t\t\t\t{RU_REF} /* ru */,\n\t\t\t);\n\t\t\tname = Localizable.strings;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

pbxproj += """/* End PBXGroup section */

/* Begin PBXNativeTarget section */
"""
pbxproj += f'\t\t{APP_ID} /* Serenity */ = {{\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {TGT_CFG_LIST} /* Build configuration list for PBXNativeTarget "Serenity" */;\n\t\t\tbuildPhases = (\n\t\t\t\t{SRC_PHASE} /* Sources */,\n\t\t\t\t{FW_PHASE} /* Frameworks */,\n\t\t\t\t{RES_PHASE} /* Resources */,\n\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Serenity;\n\t\t\tpackageProductDependencies = (\n\t\t\t);\n\t\t\tproductName = Serenity;\n\t\t\tproductReference = {APP_REF} /* Serenity.app */;\n\t\t\tproductType = "com.apple.product-type.application";\n\t\t}};\n'

pbxproj += """/* End PBXNativeTarget section */

/* Begin PBXProject section */
"""
pbxproj += f'\t\t{PROJ_ID} /* Project object */ = {{\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 1640;\n\t\t\t\tLastUpgradeCheck = 1640;\n\t\t\t\tTargetAttributes = {{\n\t\t\t\t\t{APP_ID} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;\n\t\t\t\t\t}};\n\t\t\t\t}};\n\t\t\t}};\n\t\t\tbuildConfigurationList = {PROJ_CFG_LIST} /* Build configuration list for PBXProject "Serenity" */;\n\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tru,\n\t\t\t\tBase,\n\t\t\t);\n\t\t\tmainGroup = {MAIN_GROUP};\n\t\t\tminimizedProjectReferenceProxies = 1;\n\t\t\tpreferredProjectObjectVersion = 77;\n\t\t\tproductRefGroup = {PROD_GROUP} /* Products */;\n\t\t\tprojectDirPath = "";\n\t\t\tprojectRoot = "";\n\t\t\ttargets = (\n\t\t\t\t{APP_ID} /* Serenity */,\n\t\t\t);\n\t\t}};\n'

pbxproj += """/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
"""
pbxproj += f'\t\t{RES_PHASE} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{ASSETS_BUILD} /* Assets.xcassets in Resources */,\n\t\t\t\t{EN_STRINGS} /* en in Resources */,\n\t\t\t\t{RU_STRINGS} /* ru in Resources */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'

pbxproj += """/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
"""
build_lines = "\n".join([f'\t\t\t\t{fid(f+"_build")} /* {f} in Sources */,' for f in SWIFT])
pbxproj += f'\t\t{SRC_PHASE} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{build_lines}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'

pbxproj += """/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
"""

def proj_build_settings(config):
    dbg = config == "Debug"
    return f"""{{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = {"dwarf" if dbg else '"dwarf-with-dsym"'};
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = {"YES" if dbg else "NO"};
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "{"-Onone" if dbg else "-O"}";
\t\t\t}}"""

def tgt_build_settings(config):
    return f"""{{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = Serenity/Serenity.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "Used for voice journaling";
\t\t\t\tINFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Used for voice-to-text journaling";
\t\t\t\t"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphonesimulator*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphoneos*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphonesimulator*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = YES;
\t\t\t\t"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphoneos*]" = UIStatusBarStyleDarkContent;
\t\t\t\t"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphonesimulator*]" = UIStatusBarStyleDarkContent;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks";
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.serenity.app";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}}"""

pbxproj += f'\t\t{DBG_PROJ} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {proj_build_settings("Debug")}; name = Debug; }};\n'
pbxproj += f'\t\t{REL_PROJ} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {proj_build_settings("Release")}; name = Release; }};\n'
pbxproj += f'\t\t{DBG_TGT} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {tgt_build_settings("Debug")}; name = Debug; }};\n'
pbxproj += f'\t\t{REL_TGT} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {tgt_build_settings("Release")}; name = Release; }};\n'

pbxproj += """/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
"""
pbxproj += f'\t\t{PROJ_CFG_LIST} /* Build configuration list for PBXProject "Serenity" */ = {{isa = XCConfigurationList; buildConfigurations = ({DBG_PROJ} /* Debug */, {REL_PROJ} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};\n'
pbxproj += f'\t\t{TGT_CFG_LIST} /* Build configuration list for PBXNativeTarget "Serenity" */ = {{isa = XCConfigurationList; buildConfigurations = ({DBG_TGT} /* Debug */, {REL_TGT} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};\n'

pbxproj += """/* End XCConfigurationList section */
\t};
"""
pbxproj += f'\trootObject = {PROJ_ID} /* Project object */;\n}}\n'

out = "/Users/kovesnikovegor/Desktop/Serenity/Serenity.xcodeproj/project.pbxproj"
with open(out, "w") as f:
    f.write(pbxproj)
print("Generated:", out)

# workspace
ws = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "self:">
   </FileRef>
</Workspace>
"""
ws_path = "/Users/kovesnikovegor/Desktop/Serenity/Serenity.xcodeproj/project.xcworkspace/contents.xcworkspacedata"
with open(ws_path, "w") as f:
    f.write(ws)
print("Generated:", ws_path)
