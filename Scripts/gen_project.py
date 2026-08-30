#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 ScreenClock.xcodeproj/project.pbxproj
双 Target：
  - ScreenClockSaver : .saver 屏保包（com.apple.product-type.bundle, WRAPPER_EXTENSION=saver）
  - ScreenClockStudio: 设置应用 .app，依赖并嵌入 .saver
"""
import hashlib
import os
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ_DIR = os.path.join(ROOT, "ScreenClock.xcodeproj")


def oid(*parts):
    return hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()[:24].upper()


# ---------------------------------------------------------------- 数据定义
# (路径, 文件名, 所属分组, target 成员)
SOURCES = [
    ("Shared", "ClockSettings.swift", ["saver", "app"]),
    ("Shared", "Theme.swift", ["saver", "app"]),
    ("Shared", "SettingsStore.swift", ["saver", "app"]),
    ("Shared", "FlipClockView.swift", ["saver", "app"]),
    ("Shared", "AnalogClockView.swift", ["saver", "app"]),
    ("Saver", "ScreenClockSaverView.swift", ["saver"]),
    ("Studio", "AppModel.swift", ["app"]),
    ("Studio", "StudioApp.swift", ["app"]),
    ("Studio", "ContentView.swift", ["app"]),
    ("Studio", "ClockPreview.swift", ["app"]),
    ("Studio", "SaverInstaller.swift", ["app"]),
]
PLISTS = [("Saver", "Info.plist"), ("Studio", "Info.plist")]

SAVER_TARGET = oid("target", "saver")
APP_TARGET = oid("target", "app")
SAVER_PRODUCT = oid("product", "ScreenClock.saver")
APP_PRODUCT = oid("product", "ScreenClockStudio.app")
PROJECT_OBJ = oid("project")
SCREENSAVER_FW = oid("framework", "ScreenSaver.framework")

# ---------------------------------------------------------------- ID 收集
file_refs = {}      # name -> id
build_files = []    # (id, fileRefId, settings, name)
sources_phase_files = {"saver": [], "app": []}

for folder, name, memberships in SOURCES:
    ref = oid("fileref", folder, name)
    file_refs[f"{folder}/{name}"] = ref
    for target in memberships:
        bf = oid("buildfile", target, folder, name)
        build_files.append((bf, ref, None, f"{target}:{name}"))
        sources_phase_files[target].append(bf)

for folder, name in PLISTS:
    file_refs[f"{folder}/{name}"] = oid("fileref", folder, name)

# ScreenSaver.framework build file (saver)
FW_BUILDFILE = oid("buildfile", "ScreenSaver.framework")
build_files.append((FW_BUILDFILE, SCREENSAVER_FW, None, "saver:ScreenSaver.framework"))

# app 嵌入 saver 的 CopyFiles build file
EMBED_BUILDFILE = oid("buildfile", "embed", "ScreenClock.saver")
build_files.append((EMBED_BUILDFILE, SAVER_PRODUCT, None, "app:embed saver"))

# phases
SAVER_SOURCES_PHASE = oid("phase", "saver", "sources")
SAVER_FRAMEWORKS_PHASE = oid("phase", "saver", "frameworks")
APP_SOURCES_PHASE = oid("phase", "app", "sources")
APP_FRAMEWORKS_PHASE = oid("phase", "app", "frameworks")
APP_EMBED_PHASE = oid("phase", "app", "embed")

# groups
GROUP_ROOT = oid("group", "root")
GROUP_SHARED = oid("group", "Shared")
GROUP_SAVER = oid("group", "Saver")
GROUP_STUDIO = oid("group", "Studio")
GROUP_PRODUCTS = oid("group", "Products")

# config lists / configs
PROJECT_CONF_LIST = oid("configlist", "project")
SAVER_CONF_LIST = oid("configlist", "saver")
APP_CONF_LIST = oid("configlist", "app")
conf_ids = {}
for scope in ("project", "saver", "app"):
    for cfg in ("Debug", "Release"):
        conf_ids[(scope, cfg)] = oid("config", scope, cfg)

DEP_PROXY = oid("proxy", "saver-in-app")
DEPENDENCY = oid("dependency", "app->saver")

# ---------------------------------------------------------------- 渲染辅助
def block(obj_id, isa, pairs, sort_keys=True):
    lines = [f"\t\t{obj_id} /* {isa} */ = {{", f"\t\t\tisa = {isa};"]
    keys = list(pairs.keys())
    if sort_keys:
        keys.sort()
    for k in keys:
        lines.append(f"\t\t\t{k} = {pairs[k]};")
    lines.append("\t\t};")
    return "\n".join(lines)


def q(s):
    return f'"{s}"'


sections = {k: [] for k in [
    "PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase",
    "PBXFileReference", "PBXFrameworksBuildPhase", "PBXGroup",
    "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration",
    "XCConfigurationList",
]}

# ---------------- PBXBuildFile
for bf, ref, settings, comment in build_files:
    pairs = {"isa": "PBXBuildFile", "fileRef": f"{ref} /* {comment} */"}
    if settings:
        pairs["settings"] = settings
    sections["PBXBuildFile"].append(block(bf, "PBXBuildFile", pairs))

# ---------------- PBXFileReference
def add_fileref(ref_id, pairs):
    sections["PBXFileReference"].append(block(ref_id, "PBXFileReference", pairs))

for folder, name, _ in SOURCES:
    add_fileref(file_refs[f"{folder}/{name}"], {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.swift",
        "path": q(name),
        "sourceTree": q("<group>"),
    })
for folder, name in PLISTS:
    add_fileref(file_refs[f"{folder}/{name}"], {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": q(name),
        "sourceTree": q("<group>"),
    })
add_fileref(SAVER_PRODUCT, {
    "isa": "PBXFileReference",
    "explicitFileType": q("wrapper.saver"),
    "includeInIndex": "0",
    "path": q("ScreenClock.saver"),
    "sourceTree": "BUILT_PRODUCTS_DIR",
})
add_fileref(APP_PRODUCT, {
    "isa": "PBXFileReference",
    "explicitFileType": q("wrapper.application"),
    "includeInIndex": "0",
    "path": q("ScreenClockStudio.app"),
    "sourceTree": "BUILT_PRODUCTS_DIR",
})
add_fileref(SCREENSAVER_FW, {
    "isa": "PBXFileReference",
    "lastKnownFileType": "wrapper.framework",
    "name": q("ScreenSaver.framework"),
    "path": q("System/Library/Frameworks/ScreenSaver.framework"),
    "sourceTree": "SDKROOT",
})

# ---------------- Groups
def group_block(gid, name, children, path=None):
    child_lines = ",\n".join(f"\t\t\t\t{c}" for c in children)
    body = [
        f"\t\t{gid} /* {name} */ = {{",
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
        child_lines,
        "\t\t\t);",
    ]
    if path:
        body.append(f"\t\t\tpath = {q(path)};")
    body.append("\t\t\tname = %s;" % q(name))
    body.append("\t\t};")
    return "\n".join(body)


def ref_line(key, comment):
    return f"{file_refs[key]} /* {comment} */"


sections["PBXGroup"].append(group_block(GROUP_SHARED, "Shared", [
    ref_line("Shared/ClockSettings.swift", "ClockSettings.swift"),
    ref_line("Shared/Theme.swift", "Theme.swift"),
    ref_line("Shared/SettingsStore.swift", "SettingsStore.swift"),
    ref_line("Shared/FlipClockView.swift", "FlipClockView.swift"),
    ref_line("Shared/AnalogClockView.swift", "AnalogClockView.swift"),
], path="Shared"))
sections["PBXGroup"].append(group_block(GROUP_SAVER, "Saver", [
    ref_line("Saver/ScreenClockSaverView.swift", "ScreenClockSaverView.swift"),
    ref_line("Saver/Info.plist", "Info.plist"),
], path="Saver"))
sections["PBXGroup"].append(group_block(GROUP_STUDIO, "Studio", [
    ref_line("Studio/AppModel.swift", "AppModel.swift"),
    ref_line("Studio/StudioApp.swift", "StudioApp.swift"),
    ref_line("Studio/ContentView.swift", "ContentView.swift"),
    ref_line("Studio/ClockPreview.swift", "ClockPreview.swift"),
    ref_line("Studio/SaverInstaller.swift", "SaverInstaller.swift"),
    ref_line("Studio/Info.plist", "Info.plist"),
], path="Studio"))
sections["PBXGroup"].append(group_block(GROUP_PRODUCTS, "Products", [
    f"{SAVER_PRODUCT} /* ScreenClock.saver */",
    f"{APP_PRODUCT} /* ScreenClockStudio.app */",
]))
sections["PBXGroup"].append(group_block(GROUP_ROOT, "screen-clock-saver", [
    f"{GROUP_SHARED} /* Shared */",
    f"{GROUP_SAVER} /* Saver */",
    f"{GROUP_STUDIO} /* Studio */",
    f"{GROUP_PRODUCTS} /* Products */",
]))

# ---------------- Build phases
def sources_phase(phase_id, name, bf_ids):
    files = ",\n".join(f"\t\t\t\t{bf_id} /* {name}:{i} */" for i, bf_id in enumerate(bf_ids))
    # 注释不关键，简化
    files = ",\n".join(f"\t\t\t\t{bf_id}" for bf_id in bf_ids)
    return "\n".join([
        f"\t\t{phase_id} /* Sources */ = {{",
        "\t\t\tisa = PBXSourcesBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
        files,
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
    ])


def frameworks_phase(phase_id, entries):
    files = ",\n".join(f"\t\t\t\t{e}" for e in entries)
    return "\n".join([
        f"\t\t{phase_id} /* Frameworks */ = {{",
        "\t\t\tisa = PBXFrameworksBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
        files,
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
    ])


sections["PBXSourcesBuildPhase"].append(sources_phase(SAVER_SOURCES_PHASE, "saver", sources_phase_files["saver"]))
sections["PBXSourcesBuildPhase"].append(sources_phase(APP_SOURCES_PHASE, "app", sources_phase_files["app"]))
sections["PBXFrameworksBuildPhase"].append(frameworks_phase(SAVER_FRAMEWORKS_PHASE, [
    f"{FW_BUILDFILE} /* ScreenSaver.framework in Frameworks */",
]))
sections["PBXFrameworksBuildPhase"].append(frameworks_phase(APP_FRAMEWORKS_PHASE, []))

# Copy Files：把 .saver 嵌入 app 的 Resources
sections["PBXCopyFilesBuildPhase"].append("\n".join([
    f"\t\t{APP_EMBED_PHASE} /* Embed Screen Saver */ = {{",
    "\t\t\tisa = PBXCopyFilesBuildPhase;",
    "\t\t\tdstPath = \"\";",
    "\t\t\tdstSubfolderSpec = 16;",
    "\t\t\tfiles = (",
    f"\t\t\t\t{EMBED_BUILDFILE} /* ScreenClock.saver in Resources */",
    "\t\t\t);",
    "\t\t\tname = \"Embed Screen Saver\";",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
]))

# ---------------- Container proxy / dependency
sections["PBXContainerItemProxy"].append("\n".join([
    f"\t\t{DEP_PROXY} /* PBXContainerItemProxy */ = {{",
    "\t\t\tisa = PBXContainerItemProxy;",
    f"\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;",
    f"\t\t\tproxyType = 1;",
    f"\t\t\tremoteGlobalIDString = {SAVER_TARGET};",
    "\t\t\tremoteInfo = ScreenClockSaver;",
    "\t\t};",
]))
sections["PBXTargetDependency"].append("\n".join([
    f"\t\t{DEPENDENCY} /* PBXTargetDependency */ = {{",
    "\t\t\tisa = PBXTargetDependency;",
    f"\t\t\tname = ScreenClockSaver;",
    f"\t\t\ttarget = {SAVER_TARGET} /* ScreenClockSaver */;",
    f"\t\t\ttargetProxy = {DEP_PROXY} /* PBXContainerItemProxy */;",
    "\t\t};",
]))

# ---------------- Native targets
def native_target(tid, name, product_type, product_ref, build_phases, dependencies, package_product_deps=""):
    phases = ",\n".join(f"\t\t\t\t{p}" for p in build_phases)
    deps = ",\n".join(f"\t\t\t\t{d}" for d in dependencies)
    return "\n".join([
        f"\t\t{tid} /* {name} */ = {{",
        "\t\t\tisa = PBXNativeTarget;",
        "\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;" % (
            SAVER_CONF_LIST if name == "ScreenClockSaver" else APP_CONF_LIST, name),
        "\t\t\tbuildPhases = (",
        phases,
        "\t\t\t);",
        "\t\t\tbuildRules = (",
        "\t\t\t);",
        "\t\t\tdependencies = (",
        deps,
        "\t\t\t);",
        f"\t\t\tname = {q(name)};",
        "\t\t\tproductName = %s;" % q(name),
        f"\t\t\tproductReference = {product_ref};",
        f"\t\t\tproductType = {q(product_type)};",
        "\t\t};",
    ])


sections["PBXNativeTarget"].append(native_target(
    SAVER_TARGET, "ScreenClockSaver", "com.apple.product-type.bundle",
    f"{SAVER_PRODUCT} /* ScreenClock.saver */",
    [f"{SAVER_SOURCES_PHASE} /* Sources */", f"{SAVER_FRAMEWORKS_PHASE} /* Frameworks */"],
    []))
sections["PBXNativeTarget"].append(native_target(
    APP_TARGET, "ScreenClockStudio", "com.apple.product-type.application",
    f"{APP_PRODUCT} /* ScreenClockStudio.app */",
    [f"{APP_SOURCES_PHASE} /* Sources */", f"{APP_FRAMEWORKS_PHASE} /* Frameworks */",
     f"{APP_EMBED_PHASE} /* Embed Screen Saver */"],
    [f"{DEPENDENCY} /* ScreenClockSaver */"]))

# ---------------- Project
sections["PBXProject"].append("\n".join([
    f"\t\t{PROJECT_OBJ} /* Project object */ = {{",
    "\t\t\tisa = PBXProject;",
    "\t\t\tattributes = {",
    "\t\t\t\tBuildIndependentTargetsInParallel = 1;",
    "\t\t\t\tLastSwiftUpdateCheck = 2630;",
    "\t\t\t\tLastUpgradeCheck = 2630;",
    "\t\t\t\tTargetAttributes = {",
    f"\t\t\t\t\t{SAVER_TARGET} = {{",
    "\t\t\t\t\t\tCreatedOnToolsVersion = 26.3;",
    "\t\t\t\t\t};",
    f"\t\t\t\t\t{APP_TARGET} = {{",
    "\t\t\t\t\t\tCreatedOnToolsVersion = 26.3;",
    "\t\t\t\t\t};",
    "\t\t\t\t};",
    "\t\t\t};",
    "\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"ScreenClock\" */;" % PROJECT_CONF_LIST,
    "\t\t\tcompatibilityVersion = \"Xcode 14.0\";",
    "\t\t\tdevelopmentRegion = \"zh-Hans\";",
    "\t\t\thasScannedForEncodings = 0;",
    "\t\t\tknownRegions = (",
    "\t\t\t\t\"zh-Hans\",",
    "\t\t\t\tBase,",
    "\t\t\t);",
    f"\t\t\tmainGroup = {GROUP_ROOT};",
    f"\t\t\tproductRefGroup = {GROUP_PRODUCTS} /* Products */;",
    "\t\t\tprojectDirPath = \"\";",
    "\t\t\tprojectRoot = \"\";",
    "\t\t\ttargets = (",
    f"\t\t\t\t{SAVER_TARGET} /* ScreenClockSaver */,",
    f"\t\t\t\t{APP_TARGET} /* ScreenClockStudio */,",
    "\t\t\t);",
    "\t\t};",
]))

# ---------------- Build configurations
COMMON_PROJECT = {
    "Debug": {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "GCC_C_LANGUAGE_STANDARD": q("gnu17"),
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": "(\n\t\t\t\t\"DEBUG=1\",\n\t\t\t\t\"$(inherited)\",\n\t\t\t)",
        "MACOSX_DEPLOYMENT_TARGET": q("14.0"),
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": q("macosx"),
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": q("-Onone"),
    },
    "Release": {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": q("dwarf-with-dsym"),
        "ENABLE_NS_ASSERTIONS": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": q("gnu17"),
        "GCC_NO_COMMON_BLOCKS": "YES",
        "MACOSX_DEPLOYMENT_TARGET": q("14.0"),
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SDKROOT": q("macosx"),
        "SWIFT_COMPILATION_MODE": "wholemodule",
    },
}

SAVER_BASE = {
    "CODE_SIGN_IDENTITY": q("-"),
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": q(""),
    "ENABLE_HARDENED_RUNTIME": "NO",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": q("Saver/Info.plist"),
    "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\"$(inherited)\",\n\t\t\t\t\"@loader_path/../Frameworks\",\n\t\t\t)",
    "PRODUCT_BUNDLE_IDENTIFIER": q("com.doubao.screenclock.saver"),
    "PRODUCT_NAME": q("ScreenClock"),
    "SKIP_INSTALL": "YES",
    "SWIFT_VERSION": "5.0",
    "WRAPPER_EXTENSION": q("saver"),
}
APP_BASE = {
    "CODE_SIGN_IDENTITY": q("-"),
    "CODE_SIGN_STYLE": "Automatic",
    "COMBINE_HIDPI_IMAGES": "YES",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": q(""),
    "ENABLE_HARDENED_RUNTIME": "NO",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": q("Studio/Info.plist"),
    "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\"$(inherited)\",\n\t\t\t\t\"@executable_path/../Frameworks\",\n\t\t\t)",
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": q("com.doubao.screenclock.studio"),
    "PRODUCT_NAME": q("ScreenClockStudio"),
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
}


def render_config(scope, cfg_name, settings):
    cid = conf_ids[(scope, cfg_name)]
    lines = [
        f"\t\t{cid} /* {cfg_name} */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
    ]
    for k in sorted(settings.keys()):
        v = settings[k]
        if "\n" in v:
            lines.append(f"\t\t\t\t{k} = {v};")
        else:
            lines.append(f"\t\t\t\t{k} = {v};")
    lines.append("\t\t\t};")
    lines.append("\t\t};")
    return "\n".join(lines)


for cfg_name in ("Debug", "Release"):
    sections["XCBuildConfiguration"].append(render_config("project", cfg_name, COMMON_PROJECT[cfg_name]))
    saver_cfg = dict(SAVER_BASE)
    if cfg_name == "Debug":
        saver_cfg["DEBUG_INFORMATION_FORMAT"] = "dwarf"
    else:
        saver_cfg["DEBUG_INFORMATION_FORMAT"] = q("dwarf-with-dsym")
    sections["XCBuildConfiguration"].append(render_config("saver", cfg_name, saver_cfg))
    app_cfg = dict(APP_BASE)
    if cfg_name == "Debug":
        app_cfg["DEBUG_INFORMATION_FORMAT"] = "dwarf"
    else:
        app_cfg["DEBUG_INFORMATION_FORMAT"] = q("dwarf-with-dsym")
    sections["XCBuildConfiguration"].append(render_config("app", cfg_name, app_cfg))


def config_list(clid, name, scope):
    return "\n".join([
        f"\t\t{clid} /* Build configuration list for {name} */ = {{",
        "\t\t\tisa = XCConfigurationList;",
        "\t\t\tbuildConfigurations = (",
        f"\t\t\t\t{conf_ids[(scope,'Debug')]} /* Debug */,",
        f"\t\t\t\t{conf_ids[(scope,'Release')]} /* Release */,",
        "\t\t\t);",
        "\t\t\tdefaultConfigurationIsVisible = 0;",
        f"\t\t\tdefaultConfigurationName = Release;",
        "\t\t};",
    ])


sections["XCConfigurationList"].append(config_list(PROJECT_CONF_LIST, 'PBXProject "ScreenClock"', "project"))
sections["XCConfigurationList"].append(config_list(SAVER_CONF_LIST, 'PBXNativeTarget "ScreenClockSaver"', "saver"))
sections["XCConfigurationList"].append(config_list(APP_CONF_LIST, 'PBXNativeTarget "ScreenClockStudio"', "app"))

# ---------------------------------------------------------------- 拼装
SECTION_ORDER = [
    "PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase",
    "PBXFileReference", "PBXFrameworksBuildPhase", "PBXGroup",
    "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration",
    "XCConfigurationList",
]
out = [
    "// !$*UTF8*$!",
    "{",
    "\tarchiveVersion = 1;",
    "\tclasses = {",
    "\t};",
    "\tobjectVersion = 56;",
    "\tobjects = {",
]
for sec in SECTION_ORDER:
    if not sections[sec]:
        continue
    out.append(f"/* Begin {sec} section */")
    out.extend(sections[sec])
    out.append(f"/* End {sec} section */")
out += [
    "\t};",
    f"\trootObject = {PROJECT_OBJ} /* Project object */;",
    "}",
    "",
]

os.makedirs(PROJ_DIR, exist_ok=True)
with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("generated", os.path.join(PROJ_DIR, "project.pbxproj"))
