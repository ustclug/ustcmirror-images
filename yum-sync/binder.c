// gcc -fPIC -Wall -shared -o binder.so binder.c

#define _GNU_SOURCE
#include <sys/socket.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <string.h>
// #include <stdio.h>

char *BIND_ADDRESS = NULL;
int is_ipv6 = 0;

__attribute__((constructor))
void init() {
    BIND_ADDRESS = getenv("BIND_ADDRESS");
    if (BIND_ADDRESS) {
        if (strchr(BIND_ADDRESS, ':'))
            is_ipv6 = 1;
        else
            is_ipv6 = 0;
    }
    // printf("bind address: %s, is_ipv6: %d\n", BIND_ADDRESS, is_ipv6);
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    static int (*orig_bind)(int, const struct sockaddr *, socklen_t) = NULL;
    if (!orig_bind)
        orig_bind = dlsym(RTLD_NEXT, "bind");
    if (!BIND_ADDRESS || (addr->sa_family != AF_INET && addr->sa_family != AF_INET6)) {
        return orig_bind(sockfd, addr, addrlen);
    } else {
        int type;
        unsigned int len = sizeof(type);
        if (getsockopt(sockfd, SOL_SOCKET, SO_TYPE, &type, &len)) {
            // if getsockopt() failed, don't go further
            return orig_bind(sockfd, addr, addrlen);
        }
        if (type != SOCK_STREAM) {
            // here we only want to handle TCP sockets
            return orig_bind(sockfd, addr, addrlen);
        }
        if (is_ipv6) {
            struct sockaddr_in6 addr_in6;
	        memset(&addr_in6, 0, sizeof(addr_in6));
	        addr_in6.sin6_family = AF_INET6;
            inet_pton(AF_INET6, BIND_ADDRESS, &addr_in6.sin6_addr);
            return orig_bind(sockfd, (struct sockaddr *)&addr_in6, sizeof(addr_in6));
        } else {
            struct sockaddr_in addr_in;
	        memset(&addr_in, 0, sizeof(addr_in));
	        addr_in.sin_family = AF_INET;
            inet_pton(AF_INET, BIND_ADDRESS, &addr_in.sin_addr);
            return orig_bind(sockfd, (struct sockaddr *)&addr_in, sizeof(addr_in));
        }
    }
}

int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    static int (*orig_connect)(int, const struct sockaddr *, socklen_t) = NULL;
    if (!orig_connect)
        orig_connect = dlsym(RTLD_NEXT, "connect");
    if (!BIND_ADDRESS || (addr->sa_family != AF_INET && addr->sa_family != AF_INET6)) {
        return orig_connect(sockfd, addr, addrlen);
    } else {
        bind(sockfd, addr, 0);
        return orig_connect(sockfd, addr, addrlen);
    }
}
