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

Scenery được tạo bằng seed, gồm cây và tán cây, hoa/cỏ, đá, vách núi, pha lê, tuyết, đầm lầy, dung nham và các công trình nhỏ. Cây và đá sử dụng các khối góc cạnh bất đối xứng gần lập phương/hộp chữ nhật, có mặt nghiêng và nhiều lớp màu. Nền và SpawnLocation đã có trước khi script chạy. File place bật streaming cho thế giới rộng; post effects, mây, ánh nắng, sương và bảng màu chuyển theo vùng tạo phong cách cartoon tự nhiên.

Sông có đường nhảy qua các hòn đá miễn phí và cầu có phí **150 Coins**. Đầm lầy làm chậm; nước sâu nguy hiểm. Núi lửa có vùng dung nham, Phượng Hoàng và Rồng Trắng chống được dung nham. Có **3 cổng dịch chuyển** tại đồng cỏ, cao nguyên tuyết và núi lửa, phí **250 Coins / chuyến**. Phải đứng gần cổng để sử dụng.

Khi chết, người chơi hồi sinh ở vị trí an toàn ngẫu nhiên trong **cùng vùng sinh thái**, cách vị trí chết ít nhất **200 m / 714,29 studs**. Tiến trình loài và tiền được giữ lại.

Trước khi tạo nhân vật hồi sinh, server yêu cầu tải vùng đất tại điểm đến (tối đa 3 giây cho mỗi yêu cầu). Collider của thú được bo tròn, có ma sát thấp và chừa khoảng nhỏ so với mặt sàn của bộ điều khiển. Tải xong ngoại hình hoặc thay đổi buff tốc độ sẽ giữ nguyên model/collider đang dùng; các bộ phận trang trí được bỏ neo trước khi nối vào nhân vật.

15 loài: Ốc Sên, Sâu Bướm, Chuột, Ếch, Rùa, Thỏ, Mèo, Chó Săn, Khỉ, Báo Gấm, Chuột Túi, Tinh Tinh, Ngựa Cánh, Phượng Hoàng, Rồng Trắng. Model có hình dáng và bộ phận riêng, mắt, mõm, bàn chân, hoa văn, mai, đuôi, cánh, sừng. Animation chân/cánh/đuôi chạy trên client, phối hợp thân và nhịp bước theo từng loài. Tần số bước tăng theo **tốc độ di chuyển thực tế**, nên AI chạy chậm có nhịp bước chậm và thuốc tăng tốc làm nhịp bước nhanh hơn. Sách hiển thị preview 3D của từng loài và skin đã đạt.

## Thức ăn, AI và đột biến

Thức ăn là tài nguyên chung của server: ai ăn trước sẽ lấy được, sau đó vật phẩm tái xuất hiện ở vị trí mới. Khoảng cách và trạng thái vật phẩm được máy chủ kiểm tra. AI tìm và ăn cùng nguồn thức ăn, né thú lớn, có thể tiến hóa. Người chơi ăn được AI **nhỏ hơn mình** khi đứng gần; skin thay đổi kích thước cũng ảnh hưởng khả năng săn. Người chơi khác bị đẩy khi tấn công.

Tốc chạy AI bằng **50% `WalkSpeed` mặc định của loài hiện tại**. Khi AI tiến hóa, tốc độ cũng đổi theo loài mới; việc tìm đường và tránh chướng ngại có thể khiến nó dừng hoặc đi chậm hơn.

Tốc độ tái xuất hiện thức ăn được cập nhật theo số người và AI đang sống:

```text
Hệ số toàn server = 1 + 0,25 × max(số người − 1, 0) + 0,10 × số AI
Hệ số tại điểm spawn = hệ số toàn server × 2 nếu có người sở hữu pass trong 50 m
```

Ví dụ: **1 người + 24 AI → ×3,4**, **2 người + 24 AI → ×3,65**. Điểm spawn trong bán kính **50 m / 178,57 studs** quanh người sở hữu pass có tốc độ tăng thêm **100%**; nhiều vùng pass chồng nhau vẫn chỉ nhân 2. Hệ số được áp dụng liên tục trong lúc chờ, nên vào/ra server, AI bị ăn và người có pass di chuyển đều làm thay đổi thời gian còn lại. Số điểm thức ăn đang hoạt động/chờ được giữ có giới hạn để đồ ăn vẫn rải rác trên map.

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

### Thuốc hiếm và buff tạm thời

Ba loại thuốc có **tổng xác suất xuất hiện 3%** mỗi lượt chọn thức ăn, chia đều giữa các loại. Thuốc có hình chai và màu riêng, dùng bằng **E / Ăn** khi đứng gần; không cộng độ no hoặc Coins. AI bỏ qua thuốc và tiếp tục tranh các loại thức ăn. Thuốc chưa được lấy sau 5 phút sẽ biến mất và vị trí đó được hồi vật phẩm mới, tránh chiếm hết chỗ thức ăn.

| Thuốc | Hiệu ứng trong 60 giây |
| --- | --- |
| Tốc Hành | Tốc chạy ×1,5 (+50%) |
| Săn Mồi | Random **+2 đến +4 bậc săn**, cho phép ăn AI đến bậc đó dù kích thước lớn hơn người chơi |
| Khổng Lồ | Kích thước model ×5 so với loài và skin đang dùng; khả năng săn theo kích thước cũng tăng |

Các loại khác nhau có thể hoạt động cùng lúc. Uống lại cùng loại **làm mới 60 giây**, không cộng dồn hệ số hoặc thời lượng; thuốc Săn Mồi roll lại mức +2–4. Buff không mở khóa loài vĩnh viễn. Buff tiếp tục đếm khi chết, được áp dụng lại sau hồi sinh và hết đúng hạn; thoát server sẽ mất buff. HUD có ô trạng thái riêng và đếm ngược cho từng hiệu ứng. Server quyết định thời hạn, tốc độ, kích thước và khả năng ăn AI.

## Thính và Explorer Pass

Cứ **5 phút**, server thử spawn thính với xác suất **5% × số người đang chơi**, tối đa 100%. Vị trí được đánh dấu bằng beacon và trên bản đồ **trước 3 phút**; người vào server muộn vẫn nhận được thông báo của các thính đang hoạt động. Khi hạ xuống, người đến lấy trước nhận **800–1.800 Coins**, **20–50% độ no** và **1 lần ăn quả đột biến tăng xác suất quý hiếm ×3**. Thính quá hạn sẽ biến mất. Thính mua bằng Robux cũng là mục tiêu công khai để mọi người tranh giành.

**Explorer Pass** có 5 quyền lợi:

- +50% độ no từ thức ăn.
- +50% Coins nhận từ thức ăn/thính.
- +100% tốc độ xuất hiện thức ăn trong bán kính 50 m quanh mình; vùng chồng nhau không cộng dồn.
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

Hoặc truyền `--luau /path/to/luau --compiler /path/to/luau-compile`. Các kiểm tra bao gồm cấu trúc place/map/model, biên dịch Luau, luật tiến hóa/độ no/bộ gen, startup/lưu dữ liệu, AI/food, buff và thời hạn, HUD trên màn hình nhỏ, thính và commerce trong harness CLI.

**Môi trường CLI không có Roblox engine. Vật lý, render, hiệu năng streaming và mua hàng thực tế cần kiểm tra trong Studio/experience đã publish.** Trước phát hành, thử Play, Start Server với 2 client để tranh ăn/đẩy nhau, nhảy qua sông, đi cầu/dịch chuyển mất tiền, chết/hồi sinh, thính và lưu lại sau khi thoát. Chỉnh Graphics Quality theo thiết bị để đánh giá cảnh quan và tốc độ khung hình.

Kiểm tra di chuyển bằng Ốc Sên và một loài lớn: giữ **W**, nhảy liên tục bằng **Space**, đáp xuống nền và đá rồi tiếp tục đi; thử lại sau **Reset Character** nhiều lần, với R6/R15 và thuốc Khổng Lồ đang hoạt động. Kiểm tra cả lúc tải ngoại hình hoàn tất và buff tốc độ hết hạn. Nhân vật cần tiếp tục di chuyển mà không phải đổi sang A/D/S để gỡ kẹt. Harness tự động kiểm tra khoảng hở collider, model không neo khi ghép, giữ nguyên bộ phận/velocity khi refresh, quyền điều khiển vật lý và thứ tự tải vùng hồi sinh; các kiểm tra đó không mô phỏng vật lý Roblox.
