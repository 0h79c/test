# Evolution Obby

Game Roblox Luau theo GDD: 15 loài, 5 đột biến đúng tỷ lệ, mở khóa mỗi 10 checkpoint, 140 checkpoint, Coins, reroll 500 Coins và Sách Tiến Hóa. Server quản lý tiền, mở khóa và lựa chọn dạng; client chỉ gửi yêu cầu. Đột biến lưu riêng cho từng loài.

## Chạy trong Roblox Studio

Nhanh nhất: mở `EvolutionObby.rbxlx` bằng Roblox Studio rồi Play. File place được sinh từ mã nguồn bằng `python3 tools/build_place.py`; sinh lại sau mỗi lần chỉnh code. Chọn R15 trong Game Settings để avatar nhất quán. File XML đã được kiểm tra cấu trúc, chưa được mở bằng Studio trong môi trường CLI.

Để đồng bộ code liên tục bằng Rojo:

1. Cài Rojo từ nguồn chính thức và plugin Rojo trong Studio.
2. Tại thư mục dự án chạy `rojo serve default.project.json`, kết nối plugin Rojo trong một place Baseplate mới. Xóa Baseplate mặc định để người chơi rơi xuống vùng chết đúng thiết kế.
3. Chọn avatar R15 trong Game Settings, rồi Play. Map và UI tự sinh. Nhảy qua các bệ, chạm checkpoint tuần tự, nhặt Coins và dùng ProximityPrompt ở trạm tím để mở reroll.
4. Để lưu tiến trình, publish place và bật **Game Settings → Security → Enable Studio Access to API Services** trên place thử nghiệm riêng. Không bật thử nghiệm trên dữ liệu production. Nếu DataStore lỗi, phiên chạy tạm sẽ báo “Không lưu” và không ghi đè dữ liệu cũ.

Không có Rojo: tạo Folder `Shared` trong ReplicatedStorage với ModuleScript `Config`; Folder `Game` trong ServerScriptService với ModuleScript `Character`, `World` và Script `Main`; đặt LocalScript `Main` trong StarterPlayerScripts. Dán nội dung các file tương ứng. Không dùng Script cho ModuleScript.

## Kiểm thử trong Studio

- Play: xuất hiện ở checkpoint 0 dưới dạng Ốc Sên, Speed 12 và JumpPower 40.
- Qua checkpoint 1: +100 Coins; quay lại không được thưởng lại. Nhặt cùng đồng xu chỉ được thưởng một lần trong phiên.
- Qua checkpoint 10: mở Sâu Bướm, tự chuyển dạng và roll đột biến; hồi sinh tại checkpoint gần nhất.
- Sách Tiến Hóa: chuyển miễn phí giữa dạng đã mở, dạng khóa không chọn được; chỉ số theo loài nhân buff đúng bảng.
- Trạm: thiếu tiền không reroll; đủ tiền trừ đúng 500; ra xa trạm không dùng được. Spam remote không được tạo tiền hoặc mở loài khóa.
- Phoenix miễn dung nham; các dạng khác chết khi chạm. Pegasus có lực giảm trọng lực riêng cho nhân vật, không thay đổi Workspace.Gravity. Gorilla không có cơ chế gió trong map mẫu.
- Start Server với 2 client: tiến trình và Coins độc lập; đồng xu có thể được mỗi người nhặt một lần.
- Thoát/vào place đã publish: khôi phục Coins, checkpoint, dạng và đột biến; mở đồng thời hai server sẽ bị khóa phiên để tránh ghi đè.

## Phạm vi bản đầu

Mô hình động vật là các khối placeholder được hàn vào avatar, không phải asset rig/animation hoàn chỉnh. Map mẫu kiểm tra vòng lặp tiến hóa, chưa có màn giải đố bắt buộc dạng, dung nham đuổi hoặc quạt gió. Hình dáng placeholder không tạo hitbox đặc biệt cho sâu bướm; rùa được giảm tỷ lệ avatar. Awakened có hạt sáng và lực nâng nhẹ, chưa có animation lơ lửng. Chưa tích hợp mua Coins bằng Robux; cần ID Developer Product và xử lý receipt riêng trước khi bán.

DataStore dùng lease phiên 180 giây và autosave 60 giây. Khi server bị dừng đột ngột có thể mất tiến trình chưa autosave; người chơi phải chờ lease hết nếu server trước chết. Đồng xu có thể nhặt lại sau khi vào phiên mới.

Môi trường CLI không có Roblox engine: phải chạy các kiểm thử hành vi trên trong Studio trước khi phát hành.

Đã xác minh trong CLI: 6 file Luau biên dịch thành công; `tests/config.spec.luau` kiểm tra danh sách loài, ngưỡng mở khóa và toàn bộ 100 kết quả RNG (đúng tỷ lệ 50/20/15/10/5). Chạy lại bằng `luau tests/config.spec.luau`. Project JSON và XML place hợp lệ, 5 script nhúng khớp mã nguồn. Các kiểm thử Studio, multiplayer và DataStore chưa được chạy.
