# Evolution Obby — Roblox

Game Luau với map có sẵn trong place, 15 loài có mô hình riêng, 5 đột biến, Coins, Sách Tiến Hóa và lưu tiến trình. Không cần tải model từ Toolbox hoặc cấp quyền HTTP để chơi.

## Chơi ngay

1. Tải **bản mới nhất** của `EvolutionObby.rbxlx` từ repository. Nếu đã giải nén bản cũ, thay file cũ hoặc giải nén vào thư mục mới.
2. Roblox Studio → **File → Open from File** → chọn `EvolutionObby.rbxlx`.
3. Ngay trước khi nhấn Play, bạn sẽ thấy sảnh, khu trưng bày 15 loài và đường obby trong Workspace. Nhấn **Play / F5**, nhân vật sẽ thành **Ốc Sên** tại sảnh.
4. **WASD** di chuyển, **Space** nhảy; đi theo mũi tên tới checkpoint xanh. Tại trạm tím dùng **E** hoặc nút ProximityPrompt trên điện thoại. Mở **Sách Tiến Hóa** để chọn loài đã mở khóa.
5. **Về checkpoint** đưa bạn về mốc gần nhất; **Về sảnh** đưa về trạm đầu mà giữ tiến trình. Rơi hoặc chạm bẫy sẽ hồi sinh ở checkpoint đã đạt.

**Không cần publish hoặc bật DataStore để chơi thử.** Khi chưa có quyền lưu, UI hiển thị “Chơi thử, không lưu”; map, biến hình, tiền và đột biến vẫn hoạt động trong phiên. Dừng phiên sẽ mất tiến trình tạm.

Để lưu lâu dài: publish một place thử nghiệm, rồi bật **Game Settings → Security → Enable Studio Access to API Services**. Tránh dùng place production để test vì Studio có thể truy cập cùng dữ liệu. Trong game đã publish, server tự tải và autosave dữ liệu. Nếu lỗi tải dữ liệu, phiên tạm không ghi đè dữ liệu đã lưu.

## Map và các loài

- Sảnh lớn có SpawnLocation thật, bảng hướng dẫn, trạm đột biến và khu trưng bày **15 mô hình**. Toàn bộ hình học đã nhúng trong file place, không chờ script/DataStore mới có nền đất.
- **140 checkpoint**, 14 khu cảnh quan: vườn, rừng nấm, hang pha lê, đầm lầy, bờ biển, đồng hoa, phố mèo, thung lũng, rừng khỉ, thảo nguyên, cao nguyên, núi, mây và đỉnh phượng hoàng. Đích cuối là cổng Rồng Trắng.
- Nền đảo thấp và bậc trở lại giúp người mới hồi phục khi hụt bệ. Tuyến chính có khe nhảy phù hợp với Ốc Sên; các bẫy có lối tránh.
- Đủ 15 hình dạng riêng: Ốc Sên, Sâu Bướm, Chuột, Ếch, Rùa, Thỏ, Mèo, Chó Săn, Khỉ, Báo Gấm, Chuột Túi, Tinh Tinh, Ngựa Cánh, Phượng Hoàng, Rồng Trắng. Mô hình cartoon được dựng từ Parts với mai, tai, đuôi, cánh, sừng và hoa văn riêng; có animation chân/cánh/đuôi.
- Điều khiển vẫn dùng Humanoid Roblox, hỗ trợ R6/R15. Avatar và phụ kiện gốc bị ẩn và bỏ va chạm; một collider riêng của động vật xử lý tiếp xúc. Tiny và Rùa có kích thước nhỏ hơn.

Các thử thách phụ có biển chỉ dẫn, không chặn tuyến chính:

| Checkpoint | Thử thách | Khả năng hữu ích |
| --- | --- | --- |
| 30 | Bậc nhảy cao | Ếch |
| 40 | Hầm laser thấp | Rùa; Rùa miễn laser của hầm |
| 90 | Đường chạy với tường dung nham di chuyển | Báo Gấm; Phượng Hoàng miễn dung nham |
| 110 | Quạt gió đẩy người chơi khỏi bệ | Tinh Tinh miễn gió |
| 130 | Đường bước qua dung nham | Phượng Hoàng |

Các khu phụ có điểm trở về checkpoint bằng E. Ngựa Cánh và các dạng có cánh có lực giảm rơi riêng, không đổi trọng lực của toàn server.

## Tiến hóa, đột biến và Coins

- Mỗi **10 checkpoint** mở một loài và roll đột biến cho loài mới; checkpoint 140 mở Rồng Trắng.
- Checkpoint mới thưởng **100 Coins**; đồng xu trên đường thưởng **25 Coins**, mỗi người nhặt một lần mỗi phiên. Không thưởng lại khi chạm checkpoint cũ. Đồng xu đã nhặt được ẩn riêng trên client đó.
- **15 trạm**: reroll giá **500 Coins**, server kiểm tra số dư, khoảng cách và tần suất yêu cầu. Đột biến lưu riêng cho từng loài; chọn lại loài không roll miễn phí.
- Tỷ lệ: Normal 50%, Giant 20%, Tiny 15%, Radioactive 10%, Awakened 5%. Buff Speed/Jump đúng bảng thiết kế; Giant x1.5, Tiny x0.5, Radioactive phát sáng, Awakened có hào quang. Collider các dạng lớn có giới hạn để tránh kẹt trên đường.
- Sách hiển thị thumbnail 3D, chỉ số, loài khóa và checkpoint cần đạt. UI hỗ trợ chuột và các nút cảm ứng.

Server quản lý tiến trình, Coins, mở khóa, RNG và lựa chọn dạng. DataStore có khóa theo phiên người chơi, autosave 60 giây, lease 180 giây, giải phóng khóa khi rời. Server tắt đột ngột có thể mất dữ liệu chưa autosave; người chơi có thể phải chờ lease hết. Chưa tích hợp Developer Products/Robux vì cần ID sản phẩm của experience.

## Sửa code và tạo lại place

```sh
python3 tools/build_place.py
```

Lệnh này sinh lại `EvolutionObby.rbxlx`, `src/shared/WorldLayout.luau` và `src/shared/AnimalModels.luau` bằng Python standard library. Chỉnh hình học map tại `tools/world_assets.py`, hình học động vật tại `tools/model_assets.py`; không chỉnh hai module được sinh tự động. Logic game nằm trong `src/server`, UI/animation trong `src/client`, chỉ số trong `src/shared/Config.luau`.

Hoặc cài Rojo + plugin chính thức, chạy `rojo serve default.project.json` rồi kết nối vào place sạch trong Studio. Phiên Rojo sẽ tự dựng cùng map và thư viện mô hình lúc Play. Xóa Baseplate/SpawnLocation của template khác để chúng không ảnh hưởng bẫy và spawn.

## Kiểm tra

Với Luau CLI và luau-compile trên PATH:

```sh
python3 tools/build_place.py
python3 tools/validate.py
```

Có thể chỉ định đường dẫn qua `--luau /path/to/luau --compiler /path/to/luau-compile`.

Đã chạy trong môi trường CLI:

- 12 kiểm thử Python: nền/spawn có sẵn, đầy đủ checkpoint/trạm/xu, giới hạn khe nhảy, tính nhất quán giữa map tĩnh và runtime, hình học thử thách phụ, các loài có cấu trúc riêng, tính đúng của khớp nối và XML/PrimaryPart.
- 11 file Luau biên dịch thành công; kiểm tra đầy đủ 100 kết quả RNG và ngưỡng tiến hóa.
- Chạy mã Main thật trong harness giả lập Roblox: khởi động khi DataStore bị lỗi hoặc place chưa publish, tải tiến trình, player có sẵn, tải chậm, respawn, autosave lỗi rồi phục hồi, khóa phiên và rời/vào lại khi đang tải.
- Chạy mã Character/AnimalModels thật qua 240 lần biến hình: 15 loài × 8 lần đổi đột biến × R6/R15; xác minh một collider, ẩn phụ kiện tới muộn, kích thước không cộng dồn, dọn hiệu ứng và lực giảm rơi chỉ bật khi đang rơi.

Môi trường CLI không có Roblox engine: **chưa chạy kiểm thử vật lý, render và multiplayer thực tế trong Studio**. Sau khi mở bản mới, kiểm tra spawn/Ốc Sên, các checkpoint đầu, nhặt Coins, reroll, đổi dạng, chết/hồi sinh và từng thử thách phụ. Với place đã publish, kiểm tra thoát/vào lại và Start Server với 2 client trước khi phát hành.

## Lỗi bản trước đã sửa

Bản trước gọi `GetDataStore` ngoài `pcall` trước khi dựng map. Studio chưa publish có thể ném lỗi ở ngay bước đó, khiến map, morph và UI không khởi động. Bản mới tách việc dựng world/nhân vật khỏi lưu trữ, có chế độ chơi thử và nhúng map/models thật vào place. Avatar chỉ được spawn sau khi world đã khởi tạo; người chơi có sẵn và các lần hồi sinh đều được xử lý.
