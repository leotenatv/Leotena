#include "include/flutter_inappwebview_linux/flutter_inappwebview_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>

#define FLUTTER_INAPPWEBVIEW_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_inappwebview_linux_plugin_get_type(), \
                              FlutterInappwebviewLinuxPlugin))

struct _FlutterInappwebviewLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterInappwebviewLinuxPlugin, flutter_inappwebview_linux_plugin,
              g_object_get_type())

static void flutter_inappwebview_linux_plugin_class_init(
    FlutterInappwebviewLinuxPluginClass* klass) {
  (void)klass;
}

static void flutter_inappwebview_linux_plugin_init(FlutterInappwebviewLinuxPlugin* self) {
  (void)self;
}

void flutter_inappwebview_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  (void)registrar;
}
