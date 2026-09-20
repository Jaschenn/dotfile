#!/usr/bin/env bash
# 代理体检：端口 → 出网 → 关键域名
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

FAIL=0

info "代理端口 127.0.0.1:$PROXY_PORT"
if proxy_is_up; then
    ok "在监听"
else
    warn "没在监听 —— FlClash 没开，或混合端口不是 $PROXY_PORT"
    FAIL=1
fi

use_proxy_if_available

info "出网测试"
for host in https://github.com https://raw.githubusercontent.com https://formulae.brew.sh; do
    if curl -fsS --max-time 10 -o /dev/null "$host"; then
        ok "$host"
    else
        warn "$host 不通"
        FAIL=1
    fi
done

if [ "$FAIL" = 0 ]; then
    info "出口 IP：$(curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null || echo '查询失败')"
    ok "代理正常"
else
    die "代理有问题，先解决网络再往下走"
fi
