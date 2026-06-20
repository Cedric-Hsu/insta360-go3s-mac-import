# Phase 1 测试清单

## 准备

- [ ] GO 3S 电量充足  
- [ ] 已知 WiFi 密码  
- [ ] Mac 已安装 Python 3.10+  
- [ ] `pip install insta360` 成功  

## 连接

- [ ] 系统设置中连接到 `GO 3S *.OSC`  
- [ ] `ping 192.168.42.1` 成功  

## 协议

- [ ] 运行 whitebox Client `open()` 无异常  
- [ ] `get_camera_files_list_bundle()` 返回非空列表  
- [ ] 列表路径含 `DCIM/Camera01/`  

## 下载

- [ ] 选择最小 MP4 测试 `download_file()`  
- [ ] 本地文件可播放  
- [ ] 若存在同名 LRV，一并下载  
- [ ] 记录耗时与大致速率 MB/s  

## 边界

- [ ] 下载过程中相机未休眠（或记录休眠条件）  
- [ ] 中断后重试（断点续传是否生效）  

## 记录

- [ ] 结果写入 [GO3S_COMPAT.md](./GO3S_COMPAT.md)  
- [ ] 固件版本拍照或抄录到兼容表  

## 失败时

1. 尝试 `curl -I http://192.168.42.1/DCIM/Camera01/`  
2. 查阅 [community-references.md](../docs/device-protocol/community-references.md)  
3. 在兼容表中注明失败步骤与日志  
