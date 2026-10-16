#!/usr/bin/env python3
"""Generate a disposable Xcode project for Starter + the package's hosted tests.
No XcodeGen installation or checked-in project is required.
Usage: python3 Validation/generate-project.py /private/tmp/A1R2Validation
"""
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
output = pathlib.Path(sys.argv[1]).resolve()
project = output / 'A1R2BannerStarter.xcodeproj'
project.mkdir(parents=True, exist_ok=True)
objects = {}

def obj(isa, **fields):
    key = f'{len(objects) + 1:024X}'
    objects[key] = dict(isa=isa, **fields)
    return key

def config(settings):
    configs = [obj('XCBuildConfiguration', name=name, buildSettings=settings) for name in ['Debug', 'Release']]
    return obj('XCConfigurationList', buildConfigurations=configs, defaultConfigurationName='Debug')

base = dict(ONLY_ACTIVE_ARCH='YES', ALWAYS_SEARCH_USER_PATHS='NO', SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='26.0', TVOS_DEPLOYMENT_TARGET='26.0',
            SUPPORTED_PLATFORMS='iphoneos iphonesimulator appletvos appletvsimulator',
            CODE_SIGNING_ALLOWED='NO', GENERATE_INFOPLIST_FILE='YES', ENABLE_TESTABILITY='YES',
            SWIFT_OPTIMIZATION_LEVEL='-Onone', SDKROOT='auto', TARGETED_DEVICE_FAMILY='1,2,3',
            PRODUCT_NAME='$(TARGET_NAME)', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @loader_path/Frameworks')
package = obj('XCLocalSwiftPackageReference', relativePath=str(root))
children = []
products = []

def target(name, files, kind, settings):
    sources = []
    for file in files:
        ref = obj('PBXFileReference', path=str(file), sourceTree='<absolute>', lastKnownFileType='sourcecode.swift')
        children.append(ref)
        sources.append(obj('PBXBuildFile', fileRef=ref))
    source_phase = obj('PBXSourcesBuildPhase', buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0)
    dep = obj('XCSwiftPackageProductDependency', package=package, productName='A1R2Banner')
    framework = obj('PBXBuildFile', productRef=dep)
    framework_phase = obj('PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[framework], runOnlyForDeploymentPostprocessing=0)
    ext = 'app' if kind == 'application' else 'xctest'
    product = obj('PBXFileReference', path=f'{name}.{ext}', sourceTree='BUILT_PRODUCTS_DIR', explicitFileType='wrapper.application' if ext == 'app' else 'wrapper.cfbundle')
    products.append(product)
    return obj('PBXNativeTarget', name=name, productName=name, productReference=product,
               productType=f'com.apple.product-type.{kind}', buildConfigurationList=config(base | settings),
               buildPhases=[source_phase, framework_phase], dependencies=[], buildRules=[], packageProductDependencies=[dep])

app = target('A1R2BannerStarter', sorted((root / 'Starter/A1R2BannerStarter').glob('*.swift')), 'application',
             dict(PRODUCT_BUNDLE_IDENTIFIER='com.a1r2.A1R2BannerStarter', INFOPLIST_KEY_UILaunchScreen_Generation='YES'))
tests = target('A1R2BannerTests', sorted((root / 'Tests/A1R2BannerTests').glob('*.swift')), 'bundle.unit-test',
               dict(PRODUCT_BUNDLE_IDENTIFIER='com.a1r2.A1R2BannerTests', TEST_HOST='$(BUILT_PRODUCTS_DIR)/A1R2BannerStarter.app/A1R2BannerStarter', BUNDLE_LOADER='$(TEST_HOST)'))
objects[tests]['dependencies'] = [obj('PBXTargetDependency', target=app)]
product_group = obj('PBXGroup', children=products, name='Products', sourceTree='<group>')
group = obj('PBXGroup', children=children + [product_group], sourceTree='<group>')
proj = obj('PBXProject', compatibilityVersion='Xcode 14.0', developmentRegion='en', knownRegions=['en', 'Base'],
           mainGroup=group, productRefGroup=product_group, projectDirPath='', projectRoot='', targets=[app, tests],
           buildConfigurationList=config({}), packageReferences=[package])
with (project / 'project.pbxproj').open('wb') as f:
    plistlib.dump(dict(archiveVersion='1', objectVersion='56', objects=objects, rootObject=proj), f)
scheme = project / 'xcshareddata/xcschemes'
scheme.mkdir(parents=True, exist_ok=True)
def entry(key, name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:A1R2BannerStarter.xcodeproj"/>'
(scheme / 'A1R2BannerStarter.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{entry(app, 'A1R2BannerStarter.app')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{entry(tests, 'A1R2BannerTests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{entry(app, 'A1R2BannerStarter.app')}</BuildableProductRunnable></LaunchAction>
</Scheme>''')
print(project)
