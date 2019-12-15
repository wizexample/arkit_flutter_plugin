#import "ArkitPlugin.h"
#import "FlutterArkit.h"

@implementation ArkitPlugin
NSObject<FlutterPluginRegistrar> *_registrar;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  self.registrar = registrar;
  FlutterArkitFactory* arkitFactory =
      [[FlutterArkitFactory alloc] initWithMessenger:registrar.messenger];
  [registrar registerViewFactory:arkitFactory withId:@"arkit"];

  FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"prepare_arkit" binaryMessenger:[registrar messenger]];
  ArkitPlugin* instance = [[ArkitPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

+ (NSObject<FlutterPluginRegistrar> *)registrar {
    return _registrar;
}

+ (void)setRegistrar:(NSObject<FlutterPluginRegistrar> *)newRegistrar {
    if (newRegistrar != _registrar) {
        _registrar = newRegistrar;
    }
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"isARKitWorldTrackingSessionConfigurationSupported" isEqualToString:call.method]) {
        [self isARKitWorldTrackingSessionConfigurationSupported:call result:result];
    }else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)isARKitWorldTrackingSessionConfigurationSupported:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(@(ARWorldTrackingConfiguration.isSupported));
}
@end
