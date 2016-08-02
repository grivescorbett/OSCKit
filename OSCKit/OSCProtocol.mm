#include "oscpack/OscOutboundPacketStream.h"
#include "oscpack/OscReceivedElements.h"

#import "OSCProtocol.h"

@implementation OSCProtocol

+ (NSData *)packMessage:(OSCMessage *)message {
  NSInteger bufferSize = 512 + message.estimatedSize;

  char * buffer = (char*)malloc(bufferSize * sizeof(char));

  osc::OutboundPacketStream packet(buffer, bufferSize);
  
  [self addMessageToOutputStream:packet andMessage:message];
  
  NSData *data = [NSData dataWithBytes:packet.Data() length:packet.Size()];
  
  free(buffer);

  return data;
}

+ (NSData *)packMessages:(NSArray *)messages {
  NSInteger bufferSize = 16;
  
  for(OSCMessage* message in messages) {
    bufferSize += 4;
    bufferSize += message.estimatedSize;
  }
  
  char * buffer = (char*)malloc(bufferSize * sizeof(char));
  
  osc::OutboundPacketStream packet(buffer, bufferSize);
  
  packet << osc::BeginBundleImmediate;
  
  for(OSCMessage* message in messages) {
    [self addMessageToOutputStream:packet andMessage:message];
  }
  
  packet << osc::EndBundle;
  
  NSData *data = [NSData dataWithBytes:packet.Data() length:packet.Size()];
  
  free(buffer);
  
  return data;
}

+ (void)addMessageToOutputStream:(osc::OutboundPacketStream&)stream andMessage:(OSCMessage*)message {
  stream << osc::BeginMessage([message.address UTF8String]);

  for (NSObject *arg in message.arguments) {
    if([arg isKindOfClass:[NSString class]]) {
      NSString *string = (NSString*)arg;
      const char * stringValue = [string cStringUsingEncoding:NSUTF8StringEncoding];
      stream << stringValue;
    } else if([arg isKindOfClass:[NSNumber class]]) {
      NSNumber *number = (NSNumber*)arg;
      if(CFNumberIsFloatType((CFNumberRef)number)) {
        Float32 floatValue = [number floatValue];
        stream << floatValue;
      } else {
        SInt32 integerValue = [number intValue];
        stream << integerValue;
      }
    } else {
      [[NSException exceptionWithName:@"OSCProtocolException"
        reason:[NSString stringWithFormat:@"argument is not an int, float, or string"]
        userInfo:nil] raise];
    }
  }

  stream << osc::EndMessage;
}

+ (OSCMessage*)convertMessage:(const osc::ReceivedMessage&)message {
  NSString *address = nil;
  NSMutableArray *arguments = [NSMutableArray array];

  address = [NSString stringWithUTF8String:message.AddressPattern()];

  for (osc::ReceivedMessage::const_iterator arg = message.ArgumentsBegin(); arg != message.ArgumentsEnd(); ++arg) {
    if (arg->IsInt32()) {
      [arguments addObject:@(arg->AsInt32Unchecked())];
    } else if (arg->IsFloat()) {
      [arguments addObject:@(arg->AsFloatUnchecked())];
    } else if (arg->IsString()) {
      [arguments addObject:[NSString stringWithUTF8String:arg->AsStringUnchecked()]];
    } else if (arg->IsControlPointAddress()) {
        const char* raw = arg->AsSymbolUnchecked();
        
        NSMutableArray* aVals = [NSMutableArray array];
        
        for (int i = 0; i < 8; i++) {
            int16_t val = ntohs(*((int16_t*)(raw + 2*i)));
            [aVals addObject:@(val)];
        }
        
        [arguments addObject:aVals];
    } else if (arg->IsPoint()) {
        const char* raw = arg->AsSymbolUnchecked();
        
        uint32_t x_host = ntohl(*(const uint32_t *)raw);
        uint32_t y_host = ntohl(*(const uint32_t *)(raw + 4));
        
        float x = *(float*)(&x_host);
        float y = *(float*)(&y_host);
        
        [arguments addObject:@[@(x), @(y)]];
    } else if (arg->IsNil()) {
        [arguments addObject:[NSNull null]];
    } else {
        NSLog(@"%@", arg->TypeTag());
      [[NSException exceptionWithName:@"OSCProtocolException"
                               reason:@"argument is not an int, float, or string"
                             userInfo:nil] raise];
    }
  }

  return [[OSCMessage alloc] initWithAddress:address arguments:arguments];
}

+ (void)unpackBundle:(const osc::ReceivedBundle&)bundle withCallback:(OSCMessageCallback)callback {
  for (osc::ReceivedBundle::const_iterator i = bundle.ElementsBegin();
       i != bundle.ElementsEnd(); ++i) {
    if (i->IsBundle()) {
      osc::ReceivedBundle bundledBundle(*i);
      [self unpackBundle:bundledBundle withCallback:callback];
    } else {
      osc::ReceivedMessage bundledMessage(*i);
      callback([self convertMessage:bundledMessage]);
    }
  }
}

+ (void)unpackMessages:(NSData*)data withCallback:(OSCMessageCallback)callback {
  osc::osc_bundle_element_size_t length = (int)[data length];
  const char *c_data = (char *)[data bytes];
  osc::ReceivedPacket p(c_data, length);

  if (p.IsBundle()) {
    osc::ReceivedBundle bundle(p);
    [self unpackBundle:bundle withCallback:callback];
  } else {
    osc::ReceivedMessage message(p);
    callback([self convertMessage:message]);
  }
}

@end
