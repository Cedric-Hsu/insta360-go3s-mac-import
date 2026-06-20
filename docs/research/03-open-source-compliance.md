# 开源与合规说明

## 官方立场

Insta360 客服文档写明：**相机与电脑目前仅支持有线连接，不支持无线连接。**

因此本项目的 WiFi 路径属于 **非官方、社区协议研究**，无厂商技术支持。

---

## SDK EULA 要点

若申请官方 Insta360 SDK，EULA 通常禁止：

- 逆向工程、反编译 SDK
- 单独再分发 SDK
- 与 GPL 等许可证组合导致 SDK 被「传染」

**含义**：不能既持有 SDK 授权，又依赖从 App 提取的 protobuf 做并行实现。  
**个人开源 WiFi 工具**：不申请 SDK、仅引用公开社区研究，风险相对较低，但仍需在 README 中声明非官方。

---

## 开源仓库建议

### 可以做

- MIT / Apache-2.0 许可自有代码
- 文档中引用社区协议研究链接
- 说明 protobuf 定义提取方法（不附带二进制）

### 不要做

- 在仓库中提交 Insta360 App 的 `libOne.so`、完整 APK
- 声称官方支持或与 Insta360 有关联
- 未验证就提供「删除相机文件」等危险操作

---

## README 免责声明模板

```markdown
Unofficial tool, not affiliated with Insta360.
Use at your own risk. Test with copies before deleting camera files.
Protocol reverse-engineered from community research; may break on firmware updates.
```

---

## 计划 License

代码阶段采用 **MIT**（待 `develop/insta360-go3s-wifi/` 初始化时添加 `LICENSE` 文件）。
