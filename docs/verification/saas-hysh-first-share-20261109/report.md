# 恒源生化首次分享字体修复（2026-11-09）

恒源生化首次分享可能被未结束的 Exo 字体下载阻塞。现在预览进入时并行请求原版 Exo SemiBold 和 Righteous Regular，直接将字节注册到 Flutter 内存，最多等待两秒。请求失败或超时时，本次预览与长图共用回退字形。截图只等待当前模板已解析的字体和画布图片。瑞丰中轴的 Rubik 和 Concert One 同样使用此方案。[Exo 上游](https://github.com/google/fonts/tree/main/ofl/exo) · [Righteous 上游](https://github.com/google/fonts/tree/main/ofl/righteous) · [Rubik 上游](https://github.com/google/fonts/blob/main/ofl/rubik/METADATA.pb) · [Concert One 上游](https://github.com/google/fonts/blob/main/ofl/concertone/OFL.txt)

测试验证字体请求卡住时两秒完成回退、客户端关闭、下次进入可以重试，以及长图在其他字体仍未就绪时正常生成。预览和长图使用本次会话的同一组字体结果。

荣耀 MTN-AN00 使用临时模板分发验证。检查 APK 不包含本次四款字体文件，移开原有的两款恒源生化字体缓存后冷启动。通过真实测试详情打开成果导向，首次点击即生成 739 × 1713 长图并保存到相册。导出后确认没有生成新的字体缓存，随后恢复原缓存。[预览](result-hysh-memory-preview-small.png) · [首次分享](result-hysh-memory-first-share-small.png) · [相册长图](first-share-album.jpg)
