# Contributing

感谢你对 PhyLab 的关注。

## 提交 Issue

请尽量包含：

- 设备型号与 HarmonyOS 版本
- 复现步骤
- 期望结果与实际结果
- 相关日志或截图

## 提交 Pull Request

1. Fork 本仓库并创建分支。
2. 保持 ArkTS/HarmonyOS 工程结构，不提交 `build/`、`.hvigor/`、签名材料或本地 SDK 路径。
3. 如果修改了传感器公式或 CSV 格式，请同步更新 `tests/smoke_test.py` 和文档。
4. 提交前在 DevEco Studio 中完成一次 Sync 与编译。

## 签名与隐私

不要提交：

- `*.p12`、`*.p7b`、`*.cer`、`*.csr`
- `signing/`、`local.properties`
- 包含个人 UDID、账号信息或设备序列号的日志

## License

贡献代码默认以 Apache-2.0 许可发布。
