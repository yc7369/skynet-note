#ifndef SKYNET_IMP_H
#define SKYNET_IMP_H

//skynet ���ýṹ
struct skynet_config {
	int thread;    //�߳���
	int harbor;    //harbor id
	int profile; 
	const char * daemon; //��̨ģʽ���� "./skynet.pid" 
	const char * module_path; //ģ�� ����·�� .so�ļ�·��
	const char * bootstrap;   //�����ĵ�һ����������� Ĭ�� "snlua bootstrap"
	const char * logger;      //��־�ļ�
	const char * logservice;  //��־���� Ĭ��logger
};

#define THREAD_WORKER 0
#define THREAD_MAIN 1
#define THREAD_SOCKET 2
#define THREAD_TIMER 3
#define THREAD_MONITOR 4

void skynet_start(struct skynet_config * config);

#endif
