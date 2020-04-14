#include "skynet.h"
#include "skynet_harbor.h"
#include "skynet_server.h"
#include "skynet_mq.h"
#include "skynet_handle.h"

#include <string.h>
#include <stdio.h>
#include <assert.h>

/*
 �����ַ��һ�� 32bit ������ͬһ�����ڵĵ�ַ�ĸ� 8bit ��ͬ���� 8bit ������һ���������Ǹ��ڵ㡣
 ÿ���ڵ�����һ������ķ������ harbor (�ۿ�) ����һ����Ϣ��Ŀ�ĵ�ַ�ĸ� 8 λ�ͱ��ڵ㲻ͬʱ��
 ��Ϣ��Ͷ�ݵ� harbor �����У�����ͨ�� tcp ���Ӵ��䵽Ŀ�Ľڵ�� harbor �����С�

 ��ͬ�� skynet �ڵ�� harbor ������ν�����������أ�
 ������һ������ master �ķ������ master ������Ե���Ϊһ�����̣�Ҳ���Ը�����ĳһ�� skynet �ڵ��ڲ���Ĭ�����ã���

 master �����һ���˿ڣ��� config ������Ϊ standalone ���ÿ�� skynet �ڵ㶼����� config �е� master ��ȥ���� master ��
 master �ٰ��Ų�ͬ�� harbor ������໥�������ӡ�
 master �ֺ����е� harbor ����

*/

//�����ڵ�����Լ�ע��ͷ���Ϣ��Զ�̽ڵ㡣

// harbor �����Ӧ�� skynet_context ָ��
//harbor ������Զ������ͨ�� master ͳһ������
static struct skynet_context * REMOTE = 0;
static unsigned int HARBOR = ~0;

static inline int
invalid_type(int type) {
	return type != PTYPE_SYSTEM && type != PTYPE_HARBOR;
}

void 
skynet_harbor_send(struct remote_message *rmsg, uint32_t source, int session) {
	assert(invalid_type(rmsg->type) && REMOTE);
	skynet_context_send(REMOTE, rmsg, sizeof(*rmsg) , source, PTYPE_SYSTEM , session);
}

int 
skynet_harbor_message_isremote(uint32_t handle) {
	assert(HARBOR != ~0);
	int h = (handle & ~HANDLE_MASK);
	return h != HARBOR && h !=0;
}

void
skynet_harbor_init(int harbor) {
	HARBOR = (unsigned int)harbor << HANDLE_REMOTE_SHIFT;
}

void
skynet_harbor_start(void *ctx) {
	// the HARBOR must be reserved to ensure the pointer is valid.
	// It will be released at last by calling skynet_harbor_exit
	skynet_context_reserve(ctx);	//��Ҫ����Ϊ��ʹ�����exit�ܳɹ��ͷŵ�
	REMOTE = ctx;
}

void
skynet_harbor_exit() {
	struct skynet_context * ctx = REMOTE;
	REMOTE= NULL;
	if (ctx) {
		skynet_context_release(ctx);
	}
}
