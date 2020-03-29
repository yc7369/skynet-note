#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct a {
  int n;
};

struct a *
a_create(void) {
  struct a * inst = skynet_malloc(sizeof(*inst));
  inst->n = 0;

  return inst;
}

void
a_release(struct logger * inst) {
  skynet_free(inst);
}

static int
a_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
  struct a * inst = ud;
  switch (type) {
  case PTYPE_TEXT:
    printf("service [a] message from [:%08x]: [%s] sz=%d\n",source,msg,sz);
    
    // 给对方发送1个消息
    {
    char* retstr = skynet_malloc(20);
    sprintf(retstr,"my n is %d",inst->n);
    skynet_send(context,0,source,PTYPE_TEXT,0,retstr,20);
    }
    break;
  }

  return 0;
}

int
a_init(struct a * inst, struct skynet_context *ctx, const char * parm) {
  if (parm) {
     inst->n = atoi(parm);
     printf("a_init n=%d\n",inst->n);
  }
  skynet_callback(ctx, inst, a_cb);
  skynet_command(ctx, "REG", ".a");
  return 0;
}
