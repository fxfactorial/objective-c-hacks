/* -*- objc -*- */
#ifndef TWEAK_LIB_H
#define TWEAK_LIB_H

#include <objc/objc.h>
#include <objc/runtime.h>

#import <Foundation/Foundation.h>

NSArray* get_methods_for_class(Class clz)
{
  unsigned int methodCount = 0;
  Method *methods = class_copyMethodList(clz, &methodCount);
  NSMutableArray *methods_in_obj = [NSMutableArray new];
  for (unsigned int i = 0; i < methodCount; i++) {
    Method method = methods[i];
    // Clever trick to cast into objc-string
    [methods_in_obj addObject:@(sel_getName(method_getName(method)))];
  }

  free(methods);
  return methods_in_obj;
}

void dump_local_symbols(Class clz)
{
  NSArray *return_addrs = [NSThread callStackReturnAddresses];

  NSArray *methods = get_methods_for_class(clz);
  IMP p[[methods count]];
  // Hack to be able to mutate p from inside the block
  IMP *more = p;

  [methods enumerateObjectsUsingBlock:^(NSString *meth_name,
					NSUInteger idx,
					BOOL *do_stop) {

      more[idx] =
	class_getMethodImplementation(clz,
				      NSSelectorFromString(meth_name));
    }];

  for (NSNumber *address in return_addrs) {
    Dl_info symbol_info = {NULL, NULL, NULL, NULL};
    if (dladdr((const void *)[address longValue], &symbol_info) != 0) {
      for (size_t counter = 0; counter < [methods count]; counter++) {
      	if(symbol_info.dli_saddr == more[counter]) {
      	  NSLog(@"Got match! -> Insane!");
      	}
      }
    }
  }

}

NSString* read_line(NSInputStream *sock)
{
  uint8_t d[1];
  NSMutableString *str = [NSMutableString string];

  while ([sock hasBytesAvailable]) {
    [sock read: d maxLength: 1];
    if (*d != '\n') {
      [str appendFormat: @"%c", *d];
      continue;
    }
    break;
  }
  return str;
}

void write_line(NSOutputStream *out_stream, NSString *lineStr)
{
  NSData *dt = [lineStr dataUsingEncoding: NSASCIIStringEncoding];
  [out_stream write:(const uint8_t *)[dt bytes] maxLength:[dt length]];
  unsigned char crlf[] = "\r\n";
  [out_stream write:crlf maxLength: 2];
}

NSString *decode_base64(NSData *base_64)
{
  NSString *dump = [base_64 base64EncodedStringWithOptions:0];
  NSData *decodedData =
    [[NSData alloc] initWithBase64EncodedString:dump options:0];
  NSString *decoded =
    [[NSString alloc] initWithData:decodedData
			  encoding:NSUTF8StringEncoding];
  return decoded;
}

// Hooks

%hook NSURLSession
 // This gets called by the app store for a request.
-(NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
			   completionHandler:(void (^)(NSData *data,
						       NSURLResponse *response,
						       NSError *error))cb
{
  NSString *needle = @"ipa?accessKey=";
  NSString *haystack = [[request URL] absoluteString];

  if ([haystack containsString:needle]) {
    HBLogInfo(@"ATTN!: Request as string: %@", haystack);
    HBLogInfo(@"Called datatask with request: %@, headers: %@",
	      request,
	      [request allHTTPHeaderFields]);

  }
  // Can't do:
  // `return %orig(our_request, our_wrapped_cb);`
  // because this becomes a background session and completion handlers
  // are not supported in background sessions.
  return %orig;
}

%end
#endif
