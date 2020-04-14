#ifndef poll_socket_epoll_h
#define poll_socket_epoll_h

#include <netdb.h>
#include <unistd.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>

static bool 
sp_invalid(int efd) {
	return efd == -1;
}

static int
sp_create() {
	return epoll_create(1024);
}

static void
sp_release(int efd) {
	close(efd);
}

static int 
sp_add(int efd, int sock, void *ud) {
	struct epoll_event ev;
	ev.events = EPOLLIN;
	ev.data.ptr = ud;
	if (epoll_ctl(efd, EPOLL_CTL_ADD, sock, &ev) == -1) {
		return 1;
	}
	return 0;
}

static void 
sp_del(int efd, int sock) {
	epoll_ctl(efd, EPOLL_CTL_DEL, sock , NULL);
}

static void 
sp_write(int efd, int sock, void *ud, bool enable) {
	struct epoll_event ev;
	ev.events = EPOLLIN | (enable ? EPOLLOUT : 0);
	ev.data.ptr = ud;
	epoll_ctl(efd, EPOLL_CTL_MOD, sock, &ev);
}

static int 
sp_wait(int efd, struct event *e, int max) {
	struct epoll_event ev[max];
	//epoll_event:用于回传代处理事件的数组；
    //maxevents:每次能处理的事件数；
	//timeout:等待I/O事件发生的超时值(单位毫秒)；-1相当于阻塞，0相当于非阻塞。一般用-1即可
	int n = epoll_wait(efd , ev, max, -1); //等待事件触发，当超过timeout还没有事件触发时，就超时 返回事件数量和事件集合

	//等侍注册在epfd上的socket fd的事件的发生，如果发生则将发生的sokct fd和事件类型放入到events数组中。
	//并 且将注册在epfd上的socket fd的事件类型给清空，所以如果下一个循环你还要关注这个socket fd的话，
    //则需要用epoll_ctl(epfd,EPOLL_CTL_MOD,listenfd,&ev)来重新设置socket fd的事件类型
	int i;
	for (i=0;i<n;i++) {
		e[i].s = ev[i].data.ptr;
		unsigned flag = ev[i].events;
		e[i].write = (flag & EPOLLOUT) != 0;
		e[i].read = (flag & (EPOLLIN | EPOLLHUP)) != 0;
		e[i].error = (flag & EPOLLERR) != 0;
		e[i].eof = false;
	}

	return n;
}

static void
sp_nonblocking(int fd) {
	int flag = fcntl(fd, F_GETFL, 0);
	if ( -1 == flag ) {
		return;
	}

	fcntl(fd, F_SETFL, flag | O_NONBLOCK); //设置文件描述符非阻塞状态
}

#endif
