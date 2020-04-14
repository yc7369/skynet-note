#include "skynet.h"

#include "skynet_imp.h"
#include "skynet_env.h"
#include "skynet_server.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <signal.h>
#include <assert.h>

static int
optint(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		char tmp[20];
		sprintf(tmp,"%d",opt);
		skynet_setenv(key, tmp);
		return opt;
	}
	return strtol(str, NULL, 10);
}

static int
optboolean(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		skynet_setenv(key, opt ? "true" : "false");
		return opt;
	}
	return strcmp(str,"true")==0;
}

static const char *
optstring(const char *key,const char * opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		if (opt) {
			skynet_setenv(key, opt);
			opt = skynet_getenv(key);
		}
		return opt;
	}
	return str;
}

static void
_init_env(lua_State *L) {
	lua_pushnil(L);  /* first key */  //-1��ջ��λ��
	while (lua_next(L, -2) != 0) { //��ջ�ϵ���һ�� key������,Ȼ�������ָ���ı��� key-value����ֵ����ѹ���ջ��ָ��key�������һ (next)�ԣ�.
								   //����������޸���Ԫ��,lua_next������0 
		int keyt = lua_type(L, -2); //key������
		if (keyt != LUA_TSTRING) {
			fprintf(stderr, "Invalid config table\n");
			exit(1);
		}
		const char * key = lua_tostring(L,-2); //ȡ��key
		if (lua_type(L,-1) == LUA_TBOOLEAN) { //�ж�value������ 
			int b = lua_toboolean(L,-1); //ȡ��ֵ
			skynet_setenv(key,b ? "true" : "false" );
		} else {
			const char * value = lua_tostring(L,-1); //ȡ��value
			if (value == NULL) {
				fprintf(stderr, "Invalid config table key = %s\n", key);
				exit(1);
			}
			skynet_setenv(key,value); //���û��� G[key] = value
		}
		lua_pop(L,1);//�Ƴ�value ����key ����lua_next����һ��ѭ�� lua_next���Ƴ�key
	}
	lua_pop(L,1);
}

//��������д��� �����º�
int sigign() {       //�������send��һ��disconnected socket�ϣ��ͻ��õײ��׳�һ��SIGPIPE�źš�����źŵ�ȱʡ���������˳�����
	struct sigaction sa;
	sa.sa_handler = SIG_IGN;
	sa.sa_flags = 0;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGPIPE, &sa, 0);
	return 0;
}

static const char * load_config = "\
	local result = {}\n\
	local function getenv(name) return assert(os.getenv(name), [[os.getenv() failed: ]] .. name) end\n\
	local sep = package.config:sub(1,1)\n\
	local current_path = [[.]]..sep\n\
	local function include(filename)\n\
		local last_path = current_path\n\
		local path, name = filename:match([[(.*]]..sep..[[)(.*)$]])\n\
		if path then\n\
			if path:sub(1,1) == sep then	-- root\n\
				current_path = path\n\
			else\n\
				current_path = current_path .. path\n\
			end\n\
		else\n\
			name = filename\n\
		end\n\
		local f = assert(io.open(current_path .. name))\n\
		local code = assert(f:read [[*a]])\n\
		code = string.gsub(code, [[%$([%w_%d]+)]], getenv)\n\
		f:close()\n\
		assert(load(code,[[@]]..filename,[[t]],result))()\n\
		current_path = last_path\n\
	end\n\
	setmetatable(result, { __index = { include = include } })\n\
	local config_name = ...\n\
	include(config_name)\n\
	setmetatable(result, nil)\n\
	return result\n\
";

int
main(int argc, char *argv[]) {
	const char * config_file = NULL ;
	if (argc > 1) {
		config_file = argv[1];
	} else {
		fprintf(stderr, "Need a config file. Please read skynet wiki : https://github.com/cloudwu/skynet/wiki/Config\n"
			"usage: skynet configfilename\n");
		return 1;
	}

	skynet_globalinit();	//��ʼ��skynet_node  G_NODE �ṹ�����ֲ߳̾��洢ֵΪmain_thread
	skynet_env_init();		//��ʼ��skynet_env   E      new ��һ��lua_state(�����)

	sigign();	//����signpipe�ź�

	struct skynet_config config;

#ifdef LUA_CACHELIB
	// init the lock of code cache
	luaL_initcodecache();
#endif

	struct lua_State *L = luaL_newstate(); //����lua״̬��
	luaL_openlibs(L);	// link lua lib ����lua��׼��lualib

	//lua_loadbuffer: ����buff�е�Lua���룬���û�д����򷵻�0��ͬʱ�������ĳ����ѹ������ջ��
	int err =  luaL_loadbufferx(L, load_config, strlen(load_config), "=[skynet config]", "t"); //lua_state buff buff_size ģ�飬ģ������ ģʽ��t��
	assert(err == LUA_OK); //the string "b" (only binary chunks), "t" (only text chunks),  The default is "bt".
	lua_pushstring(L, config_file);

	err = lua_pcall(L, 1, 1, 0); //����ջ�ϵĺ��� ������ʽ1 ����ֵ1 ���󲶺���Ϊ��
	if (err) {
		fprintf(stderr,"%s\n",lua_tostring(L,-1));
		lua_close(L);
		return 1;
	}
	_init_env(L);

	//���û�ȡskynet_env�е�key-value  ���ҳ�ʼ��skynet_config
	config.thread =  optint("thread",8); //�����߳�����
	config.module_path = optstring("cpath","./cservice/?.so"); //C ��д�ķ���ģ���λ�ã�ͨ��ָ cservice ����Щ .so
	config.harbor = optint("harbor", 1);                     //�ڵ��� ������ 1-255 �����������
	config.bootstrap = optstring("bootstrap","snlua bootstrap"); //�����ĵ�һ�������Լ�����������
	config.daemon = optstring("daemon", NULL);             //��̨ģʽ����
	config.logger = optstring("logger", NULL);             //��־�ļ�
	config.logservice = optstring("logservice", "logger");  //log����
	config.profile = optboolean("profile", 1);  //����ͳ��

	lua_close(L); //�رյ��´�����lua_state

	skynet_start(&config); //����skynet
	skynet_globalexit(); //����G_NODE ���ֲ߳̾��洢��key ��ɾ��pthread_key��

	return 0;
}
