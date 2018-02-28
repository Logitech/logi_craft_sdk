/*
 Copyright 2018 Logitech Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef LogiCraftClient_h
#define LogiCraftClient_h

#import <SocketRocket/SocketRocket.h>

typedef NS_ENUM(NSInteger, LogiConnectionType) {
      LOGI_WS   = 0,     // default
   // LOGI_WSS  = 1,   // will be supported in future
   // LOGI_RAW  = 2,    // will be supported in future
};

@protocol  LogiCraftClientProtocol
@required
-(void)handleCraftEvent:(NSString *)msg;
@end


/**
 Craft client connection object implementation
 */
@interface LogiCraftClient : NSObject<SRWebSocketDelegate>

@property id delegate;

// uuid to uniquely identify the connection with the plugin manager
@property (readonly) NSString *uuid;
@property (readonly) bool isConnected;

/**
  Create connection object and specify the type of transport it will use to communicate
  with the plugin manager

 @param type of connection transport (simple web socket/ secure web socket/ raw socket)
 
 @return instance of CraftClient
 */
-(instancetype) initWithConnectionType:(LogiConnectionType)type;

/**
 Connect to Craft plugin manager

 @param uuid is a universally unique identifier of type 4
        (https://en.wikipedia.org/wiki/Universally_unique_identifier#Variants)
*/

-(void) connectWithUUID:(NSString *)uuid;

/**
 Send a payload from Plugin to Craft plugin manager

 @param msg_dict dictioanry with msg_type and payload fields
 Ex: @{
     @"message_type" : @"tool_update",
     @"payload" :  @{
     @"play_task" : @"",
     @"tool" : @"some tool name <Ex:brush>",
     @"tool_option" : @"tool option <Ex:size>",
     @"tool_option_value" : @"<option value:@43>",
   }
 */
-(void) sendMessage:(NSDictionary *)msg_dict;


/**
   Disconnect from Craft plugin manager
 */
-(void) disconnect;

@end

#endif /* CraftClient_h */
