# Copyright 2025 Google LLC
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

import re

from maintenance_scheduler.tools.tools import (
    get_unresolved_incidents, get_current_time
)
from datetime import datetime, timedelta
import logging

# Configure logging for the test file
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_get_unresolved_incidents():
    result = get_unresolved_incidents()
    assert result["status"] == "success"


def test_get_current_time():
    result = get_current_time();
    # Expected result: "Wed 09 Jul 2025, 05:25PM"
    pattern = r"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) \d{2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4}, \d{2}:\d{2}(AM|PM)$"
    assert re.match(pattern, result)
