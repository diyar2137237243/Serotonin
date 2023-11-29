//
//  troller.c
//  usprebooter
//
//  Created by LL on 29/11/23.
//
#include <mach/arm/kern_return.h>
#include "troller.h"
#include <xpc/xpc.h> // copy from macOS
#include <xpc/connection.h> // copy from macOS
#include <bootstrap.h> // copy from macOS, launch.h from macOS
#include <stdio.h>
#include <unistd.h>
#include <os/object.h>
#include <time.h>
#include <sys/errno.h>
//#include <copyfile.h>
#include "util.h"
#include <IOKit/IOKitLib.h> // ioregistry_entry_t

int get_boot_manifest_hash(char hash[97]) // jbinit
{
  const UInt8 *bytes;
  CFIndex length;
  io_registry_entry_t chosen = IORegistryEntryFromPath(0, "IODeviceTree:/chosen");
  if (!MACH_PORT_VALID(chosen)) return 1;
  CFDataRef manifestHash = (CFDataRef)IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
  IOObjectRelease(chosen);
  if (manifestHash == NULL || CFGetTypeID(manifestHash) != CFDataGetTypeID())
  {
    if (manifestHash != NULL) CFRelease(manifestHash);
    return 1;
  }
  length = CFDataGetLength(manifestHash);
  bytes = CFDataGetBytePtr(manifestHash);
  for (int i = 0; i < length; i++)
  {
    snprintf(&hash[i * 2], 3, "%02X", bytes[i]);
  }
  CFRelease(manifestHash);
  return 0;
}

char* return_boot_manifest_hash_main(void) {
  static char hash[97];
  int ret = get_boot_manifest_hash(hash);
  if (ret != 0) {
    fprintf(stderr, "could not get boot manifest hash\n");
    return "lmao";
  }
    static char result[115];
    sprintf(result, "/private/preboot/%s", hash);
    return result;
}

int copyLaunchd(void) {
    kern_return_t ret = 0;
    NSString *mainBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"trolltoolsroothelper"];
    NSLog(@"usprebooter: path is %@", mainBundlePath);
    NSString *stdOut;
    NSString *stdErr;
    
//    /sbin/mount -uw /private/preboot
    spawnRoot(@"/sbin/mount", @[@"-u", @"-w", @"/private/preboot/"], &stdOut, &stdErr);
    char* prebootpath = return_boot_manifest_hash_main();
    char originallaunchd[256];
    sprintf(originallaunchd, "%s/%s", prebootpath, "originallaunchd");
    ret = unlink(originallaunchd);
    
    NSString *fakelaunchdPath = [NSString stringWithUTF8String:originallaunchd];
    NSLog(@"fakelaunchdPath: %s", originallaunchd);
    spawnRoot(mainBundlePath, @[@"filecopy", @"/sbin/launchd", fakelaunchdPath], &stdOut, &stdErr);
//    copyfile("/sbin/launchd", "/var/originallaunchd", NULL, COPYFILE_ALL);
    return ret;
}

int overwriteLaunchd(void) {
    kern_return_t ret = 0;
    
    return ret;
}

int userspaceReboot(void) {
    kern_return_t ret = 0;
    xpc_object_t xdict = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(xdict, "cmd", 5);
    xpc_object_t xreply;
    ret = unlink("/private/var/mobile/Library/MemoryMaintenance/mmaintenanced");
    if (ret && errno != ENOENT) {
        fprintf(stderr, "could not delete mmaintenanced last reboot file\n");
        return -1;
    }
    xpc_connection_t connection = xpc_connection_create_mach_service("com.apple.mmaintenanced", NULL, 0);
    if (xpc_get_type(connection) == XPC_TYPE_ERROR) {
        char* desc = xpc_copy_description((__bridge xpc_object_t _Nonnull)(xpc_get_type(connection)));
        puts(desc);
        free(desc);
        return -1;
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        char* desc = xpc_copy_description(event);
        puts(desc);
        free(desc);
    });
    xpc_connection_activate(connection);
    char* desc = xpc_copy_description(connection);
    puts(desc);
    printf("connection created\n");
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, xdict);
    if (reply) {
        char* desc = xpc_copy_description(reply);
        puts(desc);
        free(desc);
        xpc_connection_cancel(connection);
        return 0;
    }

    return -1;
}

int fuck(void) {
    kern_return_t ret = 0;
    copyLaunchd();
    userspaceReboot();
//    if (userspaceReboot() == 0) {
//        return ret;
//    }
    return ret;
}