# 磊科 N60 Pro 高功率作者功能对齐版

本项目只用于在 GitHub Actions 中手动构建磊科 N60 Pro 高功率固件，并按作者固件的软件包集合补齐功能。构建成功后会自动发布 GitHub Release。

上游源码：

<https://github.com/padavanonly/immortalwrt-mt798x-6.6>

## 构建内容

- 设备：磊科 N60 Pro（`netcore_n60-pro`）
- 平台：MediaTek Filogic / MT7986
- 无线：MediaTek `mt_wifi` 厂商驱动
- 射频：`iPAiLNA` 高功率配置、AX6000 SKU
- 功能集：补入作者多出的 127 个软件包
- Release 版本：由上游 `include/version.mk` 自动读取
- 当前版本：`24.10`
- 唯一 Release 资产：`netcore-n60pro-24.10.bin`

构建时会从上游高功率模板提取 RF 选项，并移除 N60 Pro 配方中的 `mt7915e`、`mt7986` 等 `mt76` 无线包，避免与 `mt_wifi` 冲突。USB、自动挂载和 USB LED 等设备功能保留。

作者功能包包括 KSMBD/SMB、TurboACC、EQoS、wrtbwmon、ZRAM、USB WWAN、额外 iptables/ipset、tcpdump、htop、OpenSSL 工具和 Argon 主题等。缺失功能包会导致构建在发布前直接失败，而不是静默生成精简固件。

## GitHub 构建

1. 将项目推送到 GitHub 仓库。
2. 打开 **Actions**。
3. 选择 **Build and publish Netcore N60 Pro high-power firmware**。
4. 点击 **Run workflow**。
5. 构建完成后，在 **Releases** 中下载固件。

工作流仅支持手动启动，不会因为 push、分支或标签自动运行。

Release 会自动创建或更新为 `v24.10`。如果该 Release 已存在，会删除旧资产，只上传最新的：

`netcore-n60pro-24.10.bin`

Actions Artifact 仍会保留 `SHA256SUMS`、最终 `build.config`、高功率模板、作者功能包清单、兼容补丁和构建信息，便于排查问题，但这些文件不会进入 Release。

## 上游版本

- 默认跟踪：`openwrt-24.10-6.6`
- 上游源码提交会记录到 Actions 运行摘要和 `BUILD_INFO.txt`
- 手动运行时可填写 `source_ref` 指定分支、标签或提交
- 填写 `pinned` 可使用 [`upstream.env`](upstream.env) 中记录的已知可用提交

版本号从上游 `include/version.mk` 解析，因此上游仍为 24.10 时，Release 标签和文件名都保持 `24.10`。

作者固件使用 Linux 6.6.95，而当前构建使用上游最新 Linux 6.6.133。功能包已对齐，但内核更新会导致镜像大小、模块体积和 SHA256 与作者文件不完全相同。

## 主要文件

- [`configs/n60pro-high-power.config`](configs/n60pro-high-power.config)：N60 Pro 单机型配置
- [`configs/author-parity-packages.config`](configs/author-parity-packages.config)：作者功能包清单
- [`scripts/build-n60pro-high-power.sh`](scripts/build-n60pro-high-power.sh)：构建和产物整理脚本
- [`scripts/apply-n60pro-high-power-patch.py`](scripts/apply-n60pro-high-power-patch.py)：移除冲突的 `mt76` 无线包
- [`.github/workflows/build.yml`](.github/workflows/build.yml)：GitHub Actions 工作流

## 刷机注意

- 本项目只生成 `sysupgrade` 镜像，不含 `factory` 首刷镜像。
- 仅适用于磊科 **N60 Pro**，不要用于普通 N60。
- 刷机前确认硬件版本、Bootloader 和分区布局。
- 先备份原厂固件和无线校准数据。
- 高功率配置可能提高发热、功耗和射频干扰，并受当地无线电法规限制。

## 本地构建

在 Linux 环境安装工作流中的依赖后运行：

```bash
bash scripts/build-n60pro-high-power.sh /path/to/immortalwrt-mt798x-6.6 .
```

构建文件会输出到 `dist/`。

## 权限

自动发布 Release 需要仓库允许写权限。若发布失败，请进入：

**Settings → Actions → General → Workflow permissions**

选择 **Read and write permissions**。

本项目不是 OpenWrt、ImmortalWrt 或磊科的官方项目，固件和上游代码的使用请遵守各自许可证及法规。
