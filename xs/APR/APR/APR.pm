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
package APR;

use DynaLoader ();
our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("APR.so", RTDL_GLOBAL); so we only need to link libapr.a once
# XXX: see xs/ModPerl/Const/Const.pm for issues of using 0x01
use Config ();
use constant DL_GLOBAL =>
  ( $Config::Config{dlsrc} eq 'dl_dlopen.xs' && $^O ne 'openbsd' ) ? 0x01 : 0x0;
sub dl_load_flags { DL_GLOBAL }

unless (defined &APR::XSLoader::BOOTSTRAP) {
    __PACKAGE__->bootstrap($VERSION);
    *APR::XSLoader::BOOTSTRAP = sub () { 1 };
}

1;
__END__
