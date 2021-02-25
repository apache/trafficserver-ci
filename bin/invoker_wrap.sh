#!/bin/sh
exec /opt/backtrace/bin/invoker $@ -t "/admin/bin/backtrace.sh %p"
