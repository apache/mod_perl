# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
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

our $VERSION = '0.01';

# The PerlIO layer is available only since 5.8.0 (5.7.2@13534)
use Config;
use constant PERLIO_LAYERS_ARE_ENABLED => $Config{useperlio} && $] >= 5.00703;

use APR::XSLoader ();
APR::XSLoader::load __PACKAGE__;


1;
