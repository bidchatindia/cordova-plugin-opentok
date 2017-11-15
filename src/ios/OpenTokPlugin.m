//
//  OpentokPlugin.m
//
//  Copyright (c) 2012 TokBox. All rights reserved.
//  Please see the LICENSE included with this distribution for details.
//

#import "OpentokPlugin.h"
#import "OTNetworkTest.h"

static NSString * SID_S;

@interface OpenTokPlugin () <OTNetworkTestDelegate>

@end


@implementation OpenTokPlugin{
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSMutableDictionary *subscriberDictionary;
    NSMutableDictionary *connectionDictionary;
    NSMutableDictionary *streamDictionary;
    NSMutableDictionary *callbackList;
    OTNetworkTest *_networkTest;
    
    NSTimer *timer;
}

@synthesize exceptionId;

#pragma mark -
#pragma mark Cordova Methods
-(void) pluginInitialize{
    callbackList = [[NSMutableDictionary alloc] init];
    NSLog(@"Setting webview to transparent");
    // TODO this should be configurable, whether to put native views behind or in front of webview
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.layer.zPosition = 10;
}
- (void)addEvent:(CDVInvokedUrlCommand*)command{
    NSString* event = [command.arguments objectAtIndex:0];
    [callbackList setObject:command.callbackId forKey: event];
}


#pragma mark -
#pragma mark Cordova JS - iOS bindings
#pragma mark TB Methods
/*** TB Methods
 ****/
// Called by TB.addEventListener('exception', fun...)
-(void)exceptionHandler:(CDVInvokedUrlCommand*)command{
    self.exceptionId = command.callbackId;
}

// Called by TB.initsession()
-(void)initSession:(CDVInvokedUrlCommand*)command{
    // Get Parameters
    NSString* apiKey = [command.arguments objectAtIndex:0];
    NSString* sessionId = [command.arguments objectAtIndex:1];

    // Create Session
    _session = [[OTSession alloc] initWithApiKey: apiKey sessionId:sessionId delegate:self];

    // Initialize Dictionary, contains DOM info for every stream
    subscriberDictionary = [[NSMutableDictionary alloc] init];
    streamDictionary = [[NSMutableDictionary alloc] init];
    connectionDictionary = [[NSMutableDictionary alloc] init];

    // Return Result
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by TB.initPublisher()
- (void)initPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS creating Publisher");
    BOOL bpubAudio = YES;
    BOOL bpubVideo = YES;

    // Get Parameters
    NSString* name = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];

    NSString* publishAudio = [command.arguments objectAtIndex:6];
    if ([publishAudio isEqualToString:@"false"]) {
        bpubAudio = NO;
    }
    NSString* publishVideo = [command.arguments objectAtIndex:7];
    if ([publishVideo isEqualToString:@"false"]) {
        bpubVideo = NO;
    }

    // Publish and set View
    OTPublisherSettings *publisherSettings = [[OTPublisherSettings alloc] init];
    [publisherSettings setName:name];
    [publisherSettings setCameraFrameRate:OTCameraCaptureFrameRate15FPS];
    _publisher = [[OTPublisher alloc] initWithDelegate:self settings:publisherSettings];
    // _publisher = [[OTPublisher alloc] initWithDelegate:self name:name];
    [_publisher setPublishAudio:bpubAudio];
    [_publisher setPublishVideo:bpubVideo];
    // TODO make configurable
    [self.webView.superview insertSubview:_publisher.view belowSubview:self.webView];
    //    [self.webView.superview addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(left, top, width, height)];
    if (zIndex>0) {
        _publisher.view.layer.zPosition = 1;
    }
    NSString* cameraPosition = [command.arguments objectAtIndex:8];
    if ([cameraPosition isEqualToString:@"back"]) {
        _publisher.cameraPosition = AVCaptureDevicePositionBack;
    }

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
// Helper function to update Views
- (void)updateView:(CDVInvokedUrlCommand*)command{
    NSString* callback = command.callbackId;
    NSString* sid = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    if ([sid isEqualToString:@"TBPublisher"]) {
        NSLog(@"The Width is: %d", width);
        _publisher.view.frame = CGRectMake(left, top, width, height);
        _publisher.view.layer.zPosition = 1;
    }

    // Pulls the subscriber object from dictionary to prepare it for update
    OTSubscriber* streamInfo = [subscriberDictionary objectForKey:sid];

    if (streamInfo) {
        // Reposition the video feeds!
        streamInfo.view.frame = CGRectMake(left, top, width, height);
        streamInfo.view.layer.zPosition = -1;
    }

    CDVPluginResult* callbackResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [callbackResult setKeepCallbackAsBool:YES];
    //[self.commandDelegate sendPluginResult:callbackResult toSuccessCallbackString:command.callbackId];
    [self.commandDelegate sendPluginResult:callbackResult callbackId:command.callbackId];
}

#pragma mark Publisher Methods
- (void)publishAudio:(CDVInvokedUrlCommand*)command{
    NSString* publishAudio = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Audio publishing state, %@", publishAudio);
    BOOL pubAudio = YES;
    if ([publishAudio isEqualToString:@"false"]) {
        pubAudio = NO;
    }
    [_publisher setPublishAudio:pubAudio];
}
- (void)publishVideo:(CDVInvokedUrlCommand*)command{
    NSString* publishVideo = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video publishing state, %@", publishVideo);
    BOOL pubVideo = YES;
    if ([publishVideo isEqualToString:@"false"]) {
        pubVideo = NO;
    }
    [_publisher setPublishVideo:pubVideo];
}
- (void)setCameraPosition:(CDVInvokedUrlCommand*)command{
    NSString* publishCameraPosition = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video camera position, %@", publishCameraPosition);

    if ([publishCameraPosition isEqualToString:@"back"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionBack];
    } else if ([publishCameraPosition isEqualToString:@"front"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionFront];
    }
}
- (void)destroyPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS Destroying Publisher");
    // Unpublish publisher
    [_session unpublish:_publisher error:nil];

    // Remove publisher view
    if (_publisher) {
        [_publisher.view removeFromSuperview];
    }

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


#pragma mark Session Methods
- (void)connect:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS Connecting to Session");

    // Get Parameters
    NSString* tbToken = [command.arguments objectAtIndex:0];
    [_session connectWithToken:tbToken error:nil];
}

// Called by session.disconnect()
- (void)disconnect:(CDVInvokedUrlCommand*)command{
    [_session disconnect:nil];
}

// Called by session.publish(top, left)
- (void)publish:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS Publish stream to session");
    [_session publish:_publisher error:nil];

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by session.unpublish(...)
- (void)unpublish:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS Unpublishing publisher");
    [_session unpublish:_publisher error:nil];
}

// Called by session.subscribe(streamId, top, left)
- (void)subscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS subscribing to stream");

    // Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];
    
    SID_S = sid;

    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];

    // Acquire Stream, then create a subscriber object and put it into dictionary
    OTStream* myStream = [streamDictionary objectForKey:sid];
    OTSubscriber* sub = [[OTSubscriber alloc] initWithStream:myStream delegate:self];
    [_session subscribe:sub error:nil];

    if ([[command.arguments objectAtIndex:6] isEqualToString:@"false"]) {
        [sub setSubscribeToAudio: NO];
    }
    if ([[command.arguments objectAtIndex:7] isEqualToString:@"false"]) {
        [sub setSubscribeToVideo: NO];
    }
    [subscriberDictionary setObject:sub forKey:myStream.streamId];

    [sub.view setFrame:CGRectMake(left, top, width, height)];
    if (zIndex>0) {
        sub.view.layer.zPosition = -1;
    }
    // TODO make configurable
    [self.webView.superview insertSubview:sub.view belowSubview:self.webView];
    //    [self.webView.superview addSubview:sub.view];

    // Return to JS event handler
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by session.unsubscribe(streamId, top, left)
- (void)unsubscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS unSubscribing to stream");
    //Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:sid];
    [_session unsubscribe:subscriber error:nil];
    [subscriber.view removeFromSuperview];
    [subscriberDictionary removeObjectForKey:sid];
}

// Called by session.unsubscribe(streamId, top, left)
- (void)signal:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS signaling to connectionId %@", [command.arguments objectAtIndex:2]);
    OTConnection* c = [connectionDictionary objectForKey: [command.arguments objectAtIndex:2]];
    NSLog(@"iOS signaling to connection %@", c);
    [_session signalWithType:[command.arguments objectAtIndex:0] string:[command.arguments objectAtIndex:1] connection:c error:nil];
}


#pragma mark -
#pragma mark Delegates
#pragma mark Subscriber Delegates
/*** Subscriber Methods
 ****/
- (void)subscriberDidConnectToStream:(OTSubscriberKit*)sub{
    NSLog(@"OpentTok Event : subscriber subscriberDidConnectToStream: iOS Connected To Stream");
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = sub.stream.streamId;
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData];

}
- (void)subscriber:(OTSubscriber*)subscrib didFailWithError:(OTError*)error{
    NSLog(@"OpentTok Event : subscriber didFailWithError %@", error);
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = subscrib.stream.streamId;
    NSNumber* errorCode = [NSNumber numberWithInt:1600];
    [eventData setObject: errorCode forKey:@"errorCode"];
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData];
}


#pragma mark Session Delegates
- (void)sessionDidConnect:(OTSession*)session{
    NSLog(@"OpentTok Event : sessionDidConnect: iOS Connected to Session");

    NSMutableDictionary* sessionDict = [[NSMutableDictionary alloc] init];

    // SessionConnectionStatus
    NSString* connectionStatus = @"";
    if (session.sessionConnectionStatus==OTSessionConnectionStatusConnected) {
        connectionStatus = @"OTSessionConnectionStatusConnected";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusConnecting) {
        connectionStatus = @"OTSessionConnectionStatusConnecting";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusDisconnecting) {
        connectionStatus = @"OTSessionConnectionStatusDisconnected";
    }else{
        connectionStatus = @"OTSessionConnectionStatusFailed";
    }
    [sessionDict setObject:connectionStatus forKey:@"sessionConnectionStatus"];

    // SessionId
    [sessionDict setObject:session.sessionId forKey:@"sessionId"];

    [connectionDictionary setObject: session.connection forKey: session.connection.connectionId];


    // After session is successfully connected, the connection property is available
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"status" forKey:@"connected"];
    NSMutableDictionary* connectionData = [self createDataFromConnection: session.connection];
    [eventData setObject: connectionData forKey: @"connection"];


    NSLog(@"object for session is %@", sessionDict);

    // After session dictionary is constructed, return the result!
    //    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sessionDict];
    //    NSString* sessionConnectCallback = [callbackList objectForKey:@"sessSessionConnected"];
    //    [self.commandDelegate sendPluginResult:pluginResult callbackId:sessionConnectCallback];


    [self triggerJSEvent: @"sessionEvents" withType: @"sessionConnected" withData: eventData];
}


- (void)session:(OTSession *)session connectionCreated:(OTConnection *)connection
{
    NSLog(@"OpentTok Event : session connectionCreated:");

    [connectionDictionary setObject: connection forKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionCreated" withData: data];
}

- (void)session:(OTSession *)session connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"OpentTok Event : session connectionDestroyed:");
    
    [connectionDictionary removeObjectForKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionDestroyed" withData: data];
}
- (void)session:(OTSession*)mySession streamCreated:(OTStream*)stream{
    NSLog(@"OpentTok Event : session streamCreated:");
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamCreated: stream withEventType: @"sessionEvents"];
}
- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream{
    NSLog(@"OpentTok Event : session streamDestroyed:");

    OTSubscriber * subscriber = [subscriberDictionary objectForKey:stream.streamId];
    if (subscriber) {
        NSLog(@"subscriber found, unsubscribing");
        [_session unsubscribe:subscriber error:nil];
        [subscriber.view removeFromSuperview];
        [subscriberDictionary removeObjectForKey:stream.streamId];
    }
    [self triggerStreamDestroyed: stream withEventType: @"sessionEvents"];
}
- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    
    NSLog(@"OpentTok Event : session didFailWithError: Error: %@", error);
    
    NSNumber* code = [NSNumber numberWithInt:[error code]];
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];
    [err setObject:code forKey:@"code"];

    if (self.exceptionId) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
    }
}
- (void)sessionDidDisconnect:(OTSession*)session{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    
    NSLog(@"OpentTok Event : session sessionDidDisconnect: message: %@", alertMessage);


    // Setting up event object
    for ( id key in subscriberDictionary ) {
        OTSubscriber* aStream = [subscriberDictionary objectForKey:key];
        [aStream.view removeFromSuperview];
    }
    [subscriberDictionary removeAllObjects];
    if( _publisher ){
        [_publisher.view removeFromSuperview];
    }

    // Setting up event object
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"clientDisconnected" forKey:@"reason"];
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionDisconnected" withData: eventData];
}
-(void) session:(OTSession *)session receivedSignalType:(NSString *)type fromConnection:(OTConnection *)connection withString:(NSString *)string{

    NSLog(@"OpentTok Event : session iOS Session Received signal from Connection: %@ with id %@", connection, [connection connectionId]);
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: type forKey: @"type"];
    [data setObject: string forKey: @"data"];
    if (connection.connectionId) {
        [data setObject: connection.connectionId forKey: @"connectionId"];
        [self triggerJSEvent: @"sessionEvents" withType: @"signalReceived" withData: data];
    }
}


#pragma mark Publisher Delegates
- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream{
    NSLog(@"OpentTok Event : publisher streamCreated:");
    
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamCreated: stream withEventType: @"publisherEvents"];
}
- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream{
    
    NSLog(@"OpentTok Event : publisher streamDestroyed:");
    
    [self triggerStreamDestroyed: stream withEventType: @"publisherEvents"];
}
- (void)publisher:(OTPublisher*)publisher didFailWithError:(NSError*) error {
    NSLog(@"OpentTok Event : publisher didFailWithError:%@", error );
    
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
}

#pragma mark -
#pragma mark Helper Methods
- (void)triggerStreamCreated: (OTStream*) stream withEventType: (NSString*) eventType{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];
    [data setObject: streamData forKey: @"stream"];
    [self triggerJSEvent: eventType withType: @"streamCreated" withData: data];
}
- (void)triggerStreamDestroyed: (OTStream*) stream withEventType: (NSString*) eventType{
    [streamDictionary removeObjectForKey: stream.streamId];

    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];
    [data setObject: streamData forKey: @"stream"];
    [self triggerJSEvent: eventType withType: @"streamDestroyed" withData: data];
}
- (NSMutableDictionary*)createDataFromConnection:(OTConnection*)connection{
    NSLog(@"iOS creating data from stream: %@", connection);
    NSMutableDictionary* connectionData = [[NSMutableDictionary alloc] init];
    [connectionData setObject: connection.connectionId forKey: @"connectionId" ];
    [connectionData setObject: [NSString stringWithFormat:@"%.0f", [connection.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    if (connection.data) {
        [connectionData setObject: connection.data forKey: @"data" ];
    }
    return connectionData;
}
- (NSMutableDictionary*)createDataFromStream:(OTStream*)stream{
    NSMutableDictionary* streamData = [[NSMutableDictionary alloc] init];
    [streamData setObject: stream.connection.connectionId forKey: @"connectionId" ];
    [streamData setObject: [NSString stringWithFormat:@"%.0f", [stream.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    [streamData setObject: [NSNumber numberWithInt:-999] forKey: @"fps" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasAudio] forKey: @"hasAudio" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasVideo] forKey: @"hasVideo" ];
    [streamData setObject: stream.name forKey: @"name" ];
    [streamData setObject: stream.streamId forKey: @"streamId" ];
    return streamData;
}
- (void)triggerJSEvent:(NSString*)event withType:(NSString*)type withData:(NSMutableDictionary*) data{
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    [message setObject:type forKey:@"eventType"];
    [message setObject:data forKey:@"data"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];

    NSString* callbackId = [callbackList objectForKey:event];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) screenshot:(CDVInvokedUrlCommand*)command {
    NSString* myString = [self getScreenshotImage];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:myString];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(NSString *)getScreenshotImage {
    // Define the dimensions of the screenshot you want to take (the entire screen in this case)
   
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:SID_S];
    
    UIView* screenCapture = [subscriber.view
                             snapshotViewAfterScreenUpdates:YES];
    [subscriber.view addSubview:screenCapture];
    
    UIGraphicsBeginImageContextWithOptions(subscriber.view.bounds.size,
                                           NO, [UIScreen mainScreen].scale);
    [subscriber.view drawViewHierarchyInRect:subscriber.view.bounds
               afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [screenCapture removeFromSuperview];
    
    NSData *data = UIImagePNGRepresentation(image);
    
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];

}

/***** Notes


 NSString *stringObtainedFromJavascript = [command.arguments objectAtIndex:0];
 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: stringObtainedFromJavascript];

 if(YES){
 [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackID]];
 }else{
 //Call  the Failure Javascript function
 [self.commandDelegate [pluginResult toErrorCallbackString:self.callbackID]];
 }

 ******/

- (IBAction)subscriberVideoDataReceivingStopped:(id)sender {
    
    NSLog(@"OpentTok Event : subscriberVideoDataReceivingStopped");

    [timer invalidate];
    timer = nil;
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [self triggerJSEvent:@"sessionEvents" withType:@"subscriberVideoDataReceivingStopped" withData:data];
}

#pragma mark - OTSubscriberDelegate Listeners

- (void)subscriberVideoDataReceived:(OTSubscriber *)subscriber {
    
    [timer invalidate];
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 10
                                             target: self
                                           selector: @selector(subscriberVideoDataReceivingStopped:)
                                           userInfo: nil
                                            repeats: NO];
    
    NSLog(@"OpentTok Event : subscriberVideoDataReceived");
}

- (void) subscriberDidDisconnectFromStream:(OTStream*)stream {
    
    NSLog(@"OpentTok Event : subscriberDidDisconnectFromStream");
}

- (void)subscriberVideoEnabled:(OTSubscriberKit *)subscriber reason:(OTSubscriberVideoEventReason)reason {
 
    NSLog(@"OpentTok Event : subscriberVideoEnabled %d", reason);
    [self subscriberVideoEvent:YES subscriber:subscriber reason:reason];
}

- (void)subscriberVideoDisabled:(OTSubscriberKit *)subscriber reason:(OTSubscriberVideoEventReason)reason {
   
    NSLog(@"OpentTok Event : subscriberVideoDisabled %d", reason);
    [self subscriberVideoEvent:NO subscriber:subscriber reason:reason];
}

/**
 * Sends even for subscriber video Enabled/Disabled
 * 
 * @param subscriber - subscriber connected
 * @param isEnabled - True if video enabled, false otherwise
 * @param reason - reason for video Enabling/Disabling
 */
- (void) subscriberVideoEvent:(Boolean) isEnabled subscriber:(OTSubscriberKit *)subscriber reason:(OTSubscriberVideoEventReason)reason {
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    
    NSString *result ;
    switch(reason) {
        case OTSubscriberVideoEventPublisherPropertyChanged:
            result = @"1";
            break;
        case OTSubscriberVideoEventSubscriberPropertyChanged:
            result = @"2";
            break;
        case OTSubscriberVideoEventQualityChanged:
            result = @"3";
            break;
    }
    
    [data setObject:subscriber.stream.streamId forKey:@"streamId"];
    [data setValue:result forKey:@"OTSubscriberVideoEventReason"];

    NSString *stringEvenKey;
    
    stringEvenKey = isEnabled ? @"subscriberVideoEnabled" : @"subscriberVideoDisabled";
    
    [data setValue:result forKey:@"OTSubscriberVideoEventReason"];
    [self triggerJSEvent:@"sessionEvents" withType:stringEvenKey withData:data];
}

#pragma mark Network Test

-(void)networkTest:(CDVInvokedUrlCommand*)command {
    
    // Get Parameters
    NSString* apiKey = [command.arguments objectAtIndex:0];
    NSString* sessionId = [command.arguments objectAtIndex:1];
    NSString* token = [command.arguments objectAtIndex:2];
    NSString* timeout = [command.arguments objectAtIndex:3];
    double videoBandwidth = [[command.arguments objectAtIndex:4] doubleValue];
    double audioBandwidth = [[command.arguments objectAtIndex:5] doubleValue];

    if([timeout isEqual:[NSNull null]]) {
        timeout = @"30";
    }

    timer = [NSTimer scheduledTimerWithTimeInterval: [timeout doubleValue]
                                             target: self
                                           selector: @selector(networkTestTimedOut:)
                                           userInfo: nil
                                            repeats: NO];
    
    _networkTest = [[OTNetworkTest alloc] init];
    [_networkTest runConnectivityTestWithApiKey:apiKey
                                      sessionId:sessionId
                                          token:token
                             executeQualityTest:YES
                            qualityTestDuration:10
                            videoBandwidth:videoBandwidth
                            audioBandwidth:audioBandwidth
                                       delegate:self];
}

- (IBAction)networkTestTimedOut:(id)sender {
    
    NSLog(@"OpentTok Event : networkTestTimedOut");
    
    [timer invalidate];
    timer = nil;
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setValue: @"1" forKey: @"error"];
    
    [self triggerJSEvent: @"networkTestEvents" withType: @"getStatsValue" withData: data];
}

/**
 * result -
 * OTNetworkTestResultVideoAndVoice - Good for both Video and Audio
 * OTNetworkTestResultVoiceOnly     - Audio only sessions possible (when "bps < 150K
 *                                    and > 50K" or packet loss ratio > 3%)
 * OTNetworkTestResultNotGood       - No Video and Audio (when platform connectivity
 *                                    failed or bps < 50K or packet loss ratio > 5%)
 */
- (void)networkTestDidCompleteWithResult:(enum OTNetworkTestResult)result
                                   error:(OTError*)error
{
    [timer invalidate];
    timer = nil;
    
    NSString *resultString = (result == OTNetworkTestResultVideoAndVoice) ? @"0" : (result == OTNetworkTestResultVoiceOnly ? @"1" :@"2");
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setValue: resultString forKey: @"result"];
    
    if(error == nil) {
        [data setValue: @"0" forKey: @"error"];
    }
    else {
        [data setValue: @"1" forKey: @"error"];
    }

    [self triggerJSEvent: @"networkTestEvents" withType: @"getStatsValue" withData: data];
}


@end
