# Evolution Wilds — Roblox

Game tiến hóa sinh vật trong thế giới mở: tìm thức ăn, mở 15 loài, tranh phần với AI và người chơi, săn thính, khám phá 9 vùng sinh thái. Map và mô hình được nhúng trong `EvolutionObby.rbxlx`, không cần Toolbox hoặc quyền tải asset bên ngoài.

## Chơi bản mới

1. Tải lại **EvolutionObby.rbxlx** bằng **Download raw** trên GitHub. Thay file cũ hoặc giải nén repository vào thư mục mới.
2. Roblox Studio → **File → Open from File** → chọn file → **Play / F5**.
3. Bạn xuất hiện dưới dạng Ốc Sên tại đồng cỏ. Đi tìm đồ ăn rải rác; dùng **E** hoặc nút **Ăn** khi đứng gần.
4. Khi độ no đạt **100%**, dùng **G / Tiến hóa** để mở loài tiếp theo. Độ no trở về 0% cho bậc tiến hóa mới. Mở **Sách / B** để chọn lại loài đã có.
5. Dùng **F / Đẩy** khi sát người chơi khác; loài bậc cao đẩy mạnh hơn. **M** mở bản đồ, **O** mở cửa hàng. Các nút đều dùng được trên màn hình cảm ứng.

Có thể chơi thử mà chưa publish và chưa bật DataStore. UI sẽ ghi **Chơi thử · tiến trình không lưu** khi quyền lưu chưa sẵn sàng. Để lưu lâu dài, publish một place thử nghiệm và bật **Game Settings → Security → Enable Studio Access to API Services**. Studio có thể dùng chung dữ liệu với experience đã publish; nên thử bằng experience riêng.

## Thế giới mở và hình ảnh

Map rộng **4.320 × 2.520 studs**, tương đương **1.209,6 × 705,6 m**, tổng khoảng **853.494 m²**. Mỗi vùng rộng **94.832,64 m²** theo quy đổi đã chọn **1 stud = 0,28 m**. Người chơi có thể đi theo mọi hướng từ đồng cỏ ở giữa.

| Phía bắc | Phía bắc | Phía bắc |
| --- | --- | --- |
| Rừng cổ thụ | Núi đá pha lê | Cao nguyên tuyết |
| Đồng bằng nắng | Đồng cỏ hoa | Sông ngọc lam |
| Đầm lầy phát sáng | Sa mạc hổ phách | Núi lửa tro đỏ |

Scenery được tạo bằng seed, gồm cây và tán cây, hoa/cỏ, đá, vách núi, pha lê, tuyết, đầm lầy, dung nham và các công trình nhỏ. Nền và SpawnLocation đã có trước khi script chạy. File place bật streaming cho thế giới rộng; post effects, mây, ánh nắng, sương và bảng màu chuyển theo vùng tạo phong cách cartoon tự nhiên.

Sông có đường nhảy qua các hòn đá miễn phí và cầu có phí **150 Coins**. Đầm lầy làm chậm; nước sâu nguy hiểm. Núi lửa có vùng dung nham, Phượng Hoàng và Rồng Trắng chống được dung nham. Có **3 cổng dịch chuyển** tại đồng cỏ, cao nguyên tuyết và núi lửa, phí **250 Coins / chuyến**. Phải đứng gần cổng để sử dụng.

Khi chết, người chơi hồi sinh ở vị trí an toàn ngẫu nhiên trong **cùng vùng sinh thái**, cách vị trí chết ít nhất **200 m / 714,29 studs**. Tiến trình loài và tiền được giữ lại.

15 loài: Ốc Sên, Sâu Bướm, Chuột, Ếch, Rùa, Thỏ, Mèo, Chó Săn, Khỉ, Báo Gấm, Chuột Túi, Tinh Tinh, Ngựa Cánh, Phượng Hoàng, Rồng Trắng. Model có silhouette và bộ phận riêng, mắt, hoa văn, mai, đuôi, cánh, sừng; animation chân/cánh/đuôi chạy trên client. Sách hiển thị preview 3D của từng loài và skin đã đạt.

## Thức ăn, AI và đột biến

Thức ăn là tài nguyên chung của server: ai ăn trước sẽ lấy được, sau đó vật phẩm tái xuất hiện ở vị trí mới. Khoảng cách và trạng thái vật phẩm được máy chủ kiểm tra. AI tìm và ăn cùng nguồn thức ăn, né thú lớn, có thể tiến hóa. Người chơi ăn được AI **nhỏ hơn mình** khi đứng gần; skin thay đổi kích thước cũng ảnh hưởng khả năng săn. Người chơi khác bị đẩy khi tấn công.

| Thức ăn thường | Độ no cơ bản |
| --- | --- |
| Quả mọng | 0,5% |
| Lá non | 1% |
| Táo | 2% |
| Nấm | 3% |
| Cá | 5% |
| Thịt | 7% |
| Trái cây quý | 10% |

Thức ăn còn thưởng Coins theo loại. **Quả đột biến** hiếm có xác suất **1,2%** khi chọn một lượt spawn thức ăn; không có trạm đột biến. Ăn quả sẽ roll bộ gen cho **loài đang dùng**, lưu riêng theo loài.

| Bộ gen | Quả hiếm thường | Quả trong thính |
| --- | ---: | ---: |
| Nguyên bản | 75% | 25% |
| Khổng lồ | 8% | 24% |
| Tí hon | 7% | 21% |
| Phát quang | 7% | 21% |
| Thức tỉnh | 3% | 9% |

Các skin quý có bảng màu nổi bật, thay đổi kích thước theo bộ gen, bộ phận phụ và hào quang. Khổng lồ có sừng; Tí hon có chi tiết faerie; Phát quang có gai/pha lê; Thức tỉnh có vương miện, chi tiết vàng và halo. Buff tốc độ/nhảy và kích thước do server áp dụng, collider có giới hạn để tránh kẹt vào cảnh quan.

## Thính và Explorer Pass

Cứ **5 phút**, server thử spawn thính với xác suất **5% × số người đang chơi**, tối đa 100%. Vị trí được đánh dấu bằng beacon và trên bản đồ **trước 3 phút**; người vào server muộn vẫn nhận được thông báo của các thính đang hoạt động. Khi hạ xuống, người đến lấy trước nhận **800–1.800 Coins**, **20–50% độ no** và **1 lần ăn quả đột biến tăng xác suất quý hiếm ×3**. Thính quá hạn sẽ biến mất. Thính mua bằng Robux cũng là mục tiêu công khai để mọi người tranh giành.

**Explorer Pass** có 4 quyền lợi:

- +50% độ no từ thức ăn.
- +50% Coins nhận từ thức ăn/thính.
- 2 lượt reroll miễn phí khi ăn quả đột biến, dành cho bộ gen vừa roll; không còn reroll bằng 500 Coins.
- Nút hồi sinh gần chỗ chết, dùng trong 2 phút sau khi chết; hồi chiêu 3 phút.

### Cấu hình Robux khi đã có ID

Bạn chưa có ID nên mua bằng Robux đang **tắt**, cửa hàng hiển thị lý do. Tìm đồ ăn, tiến hóa và thính ngẫu nhiên vẫn chơi được.

1. Publish experience của bạn lên Roblox.
2. Trong **Creator Hub**, tạo **Game Pass** và **Developer Product** cho experience; chọn giá của bạn và sao chép ID số.
3. Sửa `src/shared/Config.luau`:

```lua
Config.Commerce = {
    PassId = 0, -- thay bằng ID Game Pass
    SupplyDropProductId = 0, -- thay bằng ID Developer Product mua thính
}
```

4. Chạy `python3 tools/build_place.py`, mở place mới rồi publish. Nếu sửa trực tiếp trong Studio, sửa module **ReplicatedStorage → Shared → Config** và publish.
5. Thử mua trên experience đã publish. Giá được lấy từ Roblox; UI không dùng giá giả. Server xác minh quyền sở hữu pass. Developer Product chỉ được cấp qua `ProcessReceipt`; receipt được ghi vào dữ liệu bền vững trước khi công nhận, không dựa vào thông báo hoàn tất từ client.

## Sửa code và tạo lại place

```sh
python3 tools/build_place.py
```

Lệnh dùng Python standard library, sinh `EvolutionObby.rbxlx` cùng `src/shared/WorldLayout.luau`, `WorldConfig.luau` và `AnimalModels.luau`. Tên file place được giữ để tương thích đường dẫn tải cũ.

- `tools/world_assets.py`: seed, bố cục vùng sinh thái và hình học map. Đổi seed tại đây rồi rebuild để tạo lại cảnh quan; các vùng vẫn giữ vị trí dễ đọc trên bản đồ.
- `tools/model_assets.py`, `tools/model_runtime.luau`: model gốc và skin đột biến.
- `src/shared/Config.luau`: chỉ số loài, thức ăn, spawn, thính và ID cửa hàng.
- `src/server`: tiến trình/lưu trữ, map, AI/thức ăn, combat, thính, commerce.
- `src/client`: HUD, bản đồ, sách 3D, animation và hiệu ứng môi trường.

Không chỉnh tay các module sinh tự động vì rebuild sẽ ghi lại. Có thể dùng Rojo với `default.project.json`: vào place sạch, chạy `rojo serve`, kết nối plugin Rojo rồi Play; server dựng world và thư viện model từ cùng dữ liệu. Place XML là cách mở nhanh để thấy map ngay trong chế độ chỉnh sửa.

## Kiểm tra

Với Luau CLI và `luau-compile` trên PATH:

```sh
python3 tools/build_place.py
python3 tools/validate.py
```

Hoặc truyền `--luau /path/to/luau --compiler /path/to/luau-compile`. Các kiểm tra bao gồm cấu trúc place/map/model, biên dịch Luau, luật tiến hóa/độ no/bộ gen, startup/lưu dữ liệu, AI/food, thính và commerce trong harness CLI.

**Môi trường CLI không có Roblox engine. Vật lý, render, hiệu năng streaming và mua hàng thực tế cần kiểm tra trong Studio/experience đã publish.** Trước phát hành, thử Play, Start Server với 2 client để tranh ăn/đẩy nhau, nhảy qua sông, đi cầu/dịch chuyển mất tiền, chết/hồi sinh, thính và lưu lại sau khi thoát. Chỉnh Graphics Quality theo thiết bị để đánh giá cảnh quan và tốc độ khung hình.
