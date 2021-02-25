#!/bin/env perl
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use lib '/opt/ats-6.1.x/share/perl5';

use Apache::TS::Config::Records;
use File::Copy;

chdir("/opt/ats-6.1.x");

my $recedit = new Apache::TS::Config::Records(file => "etc/trafficserver/records.config");

$recedit->set(conf => "proxy.config.exec_thread.autoconfig",  val => "0");
$recedit->set(conf => "proxy.config.exec_thread.limit",  val => "4");
$recedit->set(conf => "proxy.config.cache.ram_cache.size",  val => "256M");
$recedit->set(conf => "proxy.config.cache.ram_cache_cutoff",  val => "32M");
$recedit->set(conf => "proxy.config.url_remap.remap_required",  val => "0");
#$recedit->set(conf => "proxy.config.url_remap.pristine_host_hdr",  val => "0");
$recedit->set(conf => "proxy.config.http.insert_response_via_str",  val => "1");
$recedit->set(conf => "proxy.config.http.insert_request_via_str",  val => "1");
$recedit->set(conf => "proxy.config.http.cache.ignore_client_cc_max_age",  val => "0");
$recedit->set(conf => "proxy.config.http.normalize_ae_gzip",  val => "0");
$recedit->set(conf => "proxy.config.dns.search_default_domains",  val => "0");
$recedit->set(conf => "proxy.config.http.response_server_enabled",  val => "2");

$recedit->write(file => "etc/trafficserver/records.config");
