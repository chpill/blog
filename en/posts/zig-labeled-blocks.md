---
title: Zig labeled Blocks
author: Etienne Spillemaeker
published: 2026-04-09
---

[Labeled blocks in Zig][1] are an interesting way of reducing lexical scope
clutter without code golf. Imagine some mundane code from an HTTP server,
preparing to send a json payload to a HTTP client:

```zig
const response_body_as_json = blk: {
    var writer: std.Io.Writer.Allocating = .init(allocator);
    var stringifier: std.json.Stringify = .{ .writer = &writer.writer };

    try stringifier.write(TypeYouWantToRenderAsJSON{
        .some_field = &some_value,
        .a_string = "whatever",
    });
    break :blk writer.writer.buffered();
};
defer allocator.free(response_body_as_json);
```

In this sample, we don't pollute the current lexical scope with `writer` or
`stringifier`. This did not seem valuable to me at first. But after a few weeks
of writing Zig for a toy project, a recurring source of struggle has been that
my scopes are getting bigger than I'm confortable with. That was unexpected,
hence this note.

Another benefit is that by using short labeled blocks, you can get away with
using generic and uninspired names inside of them! For example, in my current
project, using `writer` as a variable name in a large lexical scope is begging
for a collision, and having various `<x>_writer` gets tedious fast.

This new understanding led me to refactor a lot of my code and presented me with
one weird corner of the current implementation of Zig. Here's the heart of the
hypotetical HTTP server:

```zig
<...>
const address = try Io.net.IpAddress.parseIp6("::", 3000);

var listener = try address.listen(io, .{ .reuse_address = true });
defer listener.deinit(io);

while (true) {
    const stream = try listener.accept(io);
    defer stream.close(io);

    var http_server = blk: {
        var reader_buf: [4096]u8 = undefined;
        var writer_buf: [4096]u8 = undefined;

        var reader = stream.reader(io, &reader_buf);
        var writer = stream.writer(io, &writer_buf);

        break :blk std.http.Server.init(&reader.interface, &writer.interface);
    };

    var req = try http_server.receiveHead();

    <...>
}
```

This works today, but there is a heated debate on whether it should work in the
future. The block does its job of cleaning up `reader`, `reader_buf`, `writer`
and `writer_buf` from the lexical scope of its parent (the `while` block), but
the lifetimes of those variables are actually tied to the parent!. There are
[various][2] [discussions][3] and an [issue][4] discussing that behavior. Some
people think that the stack memory allocated in the block should not be
available outside of it, and that the compiler should be able to reuse that
memory, in the same way the memory of a function stack frame can be reused as
soon as a function returns. Accessing a pointer referencing memory that was
allocated in the block would be like accessing a dangling pointer referencing
memory inside the stack frame of a function that has already returned.

Interestingly, there is a way to rewrite the previous code to surface the intent
of coupling the lifetimes of the locals without cluttering the lexical scope
with `inline fn`:

```zig
inline fn make_server(io: Io, stream: Io.net.Stream) std.http.Server {
    var reader_buf: [4096]u8 = undefined;
    var writer_buf: [4096]u8 = undefined;
    var reader = stream.reader(io, &reader_buf);
    var writer = stream.writer(io, &writer_buf);

    return std.http.Server.init(&reader.interface, &writer.interface);
}
```

and then calling var `http_server = make_server(io, stream);`.

To be clear, in the case of this particular http_server, I feel like it's
probably best to do neither of those things, but I'm too new to Zig to have
strong opinions about that.

[1]: https://ziglang.org/documentation/master/#Blocks
[2]: https://ziggit.dev/t/what-makes-ban-returning-pointer-to-stack-memory-difficult/9380/28?u=chpill
[3]: https://zsf.zulipchat.com/#narrow/channel/454360-compiler/topic/Lifetime.20of.20locals/with/561387387
[4]: https://codeberg.org/ziglang/zig/issues/30078
