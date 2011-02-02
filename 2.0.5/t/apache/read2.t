use Apache::TestRequest 'POST_BODY_ASSERT';
print POST_BODY_ASSERT "/TestApache__read2",
    content => "foobar";
