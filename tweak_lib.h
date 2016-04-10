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
      	if(symbol_info.dli_saddr == &more[counter]) {
      	  NSLog(@"Got match! -> Insane!");
      	}
      }
    }
  }

}

#endif
