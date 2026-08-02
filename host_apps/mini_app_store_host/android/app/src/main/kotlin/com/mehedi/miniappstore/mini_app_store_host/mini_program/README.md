# Mini-Program Android Integration

The `generated/` directory is owned by `mini_program_tooling` and may be
updated by `miniprogram host capability init` commands. Do not place host
application code in this directory.

Keep host-owned native features beside `MainActivity.kt` or in a separate
application package. `MainActivity.kt` contains one stable call to
`MiniProgramNativeSetup.register(...)`.
