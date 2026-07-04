{{flutter_js}}
{{flutter_build_config}}

// Safely determine which renderer to use based on compiled builds
const builds = (_flutter && _flutter.buildConfig && _flutter.buildConfig.builds) || [];
const hasHtmlBuild = builds.some(function(b) { return b && b.renderer === "html"; });
const hasCanvasKitBuild = builds.some(function(b) { return b && b.renderer === "canvaskit"; });

const loaderConfig = {};
if (hasHtmlBuild) {
  loaderConfig.renderer = "html";
} else if (hasCanvasKitBuild) {
  loaderConfig.renderer = "canvaskit";
}

_flutter.loader.load({
  config: loaderConfig,
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
