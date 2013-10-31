# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package APR::PerlIO;

require 5.006001;

our $VERSION = '0.009000';

# The PerlIO layer is available only since 5.8.0 (5.7.2@13534)
use Config;
use constant PERLIO_LAYERS_ARE_ENABLED => $Config{useperlio} && $] >= 5.00703;

use APR ();
use APR::XSLoader ();
APR::XSLoader::load __PACKAGE__;


1;
