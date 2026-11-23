# Phát hiện biến thể SNP/Indel trên dữ liệu ONT HG003 bằng Clair3

## 1. Giới thiệu

Dự án này thực hiện đánh giá mô hình **Clair3 v2.0.2** trong bài toán phát hiện các biến thể di truyền SNP (Single Nucleotide Polymorphism) và Indel (Insertion/Deletion) từ dữ liệu giải trình tự Oxford Nanopore Technologies (ONT) của mẫu HG003 trên nhiễm sắc thể 20.

Mục tiêu của dự án là so sánh hiệu quả của mô hình Clair3 đã được huấn luyện trước (pretrained baseline) với hai mô hình được fine-tuning bằng các learning rate khác nhau.

Quy trình thực nghiệm bao gồm:

- Chuẩn bị dữ liệu và phân chia các vùng trên bộ gen.
- Chạy mô hình Clair3 pretrained làm baseline.
- Fine-tuning nhánh Pileup của Clair3.
- Lưu checkpoint sau mỗi epoch để có thể tiếp tục huấn luyện.
- Chạy dự đoán biến thể bằng các mô hình sau fine-tuning.
- Đánh giá kết quả bằng hap.py và bộ dữ liệu chuẩn GIAB.
- So sánh Precision, Recall, F1-score cho SNP và Indel.
- Phân tích kết quả, ưu điểm, hạn chế và khả năng cải thiện mô hình.

## 2. Bộ dữ liệu (Dataset)

Dự án sử dụng dữ liệu giải trình tự ONT của mẫu HG003 thuộc bộ dữ liệu chuẩn Genome in a Bottle (GIAB).

Thông tin dữ liệu:

| Thuộc tính | Giá trị |
|---|---|
| Mẫu dữ liệu | HG003 |
| Công nghệ giải trình tự | Oxford Nanopore Technologies (ONT) |
| Bộ gen tham chiếu | GRCh38 |
| Nhiễm sắc thể | chr20 |
| Vùng dữ liệu | chr20:100000–300000 |
| Bộ dữ liệu chuẩn | GIAB HG003 v4.2.1 |
| Định dạng dữ liệu | BAM, FASTA, VCF, BED |

**Nguồn dữ liệu:**

https://www.bio8.cs.hku.hk/clair3/demo/quick_demo/ont/

### 2.1. Phân chia dữ liệu

Dữ liệu được chia thành ba vùng không chồng lấn:

| Tập dữ liệu | Vùng trên nhiễm sắc thể 20 | Mục đích |
|---|---|---|
| Training | chr20:100000–190000 | Fine-tuning mô hình |
| Validation | chr20:192000–230000 | Theo dõi quá trình huấn luyện |
| Testing | chr20:232000–300000 | Đánh giá mô hình |

Các vùng huấn luyện và đánh giá được kết hợp với GIAB confident regions nhằm hạn chế ảnh hưởng từ những vị trí chưa có nhãn chuẩn đáng tin cậy.

**Lưu ý:** Thực nghiệm chỉ sử dụng vùng demo dài khoảng 200 kb trên nhiễm sắc thể 20, không phải toàn bộ nhiễm sắc thể 20.

## 3. Bài toán và kiến trúc mô hình

### 3.1. Phát biểu bài toán

Bài toán đặt ra là phát hiện các biến thể di truyền từ dữ liệu giải trình tự ONT, bao gồm:

- **SNP:** Biến thể thay thế một nucleotide tại một vị trí trên bộ gen.
- **Indel:** Biến thể chèn hoặc xóa một hay nhiều nucleotide so với bộ gen tham chiếu.

Dữ liệu ONT cho phép đọc các đoạn DNA dài, tuy nhiên quá trình giải trình tự có thể xuất hiện lỗi, đặc biệt tại các vùng nucleotide lặp lại hoặc vùng có cấu trúc phức tạp.

Do đó, bài toán yêu cầu mô hình phân biệt được biến thể sinh học thực sự với các sai lệch phát sinh trong quá trình giải trình tự.

### 3.2. Kiến trúc Clair3

Clair3 kết hợp hai thành phần chính:

**1. Pileup Model**

- Sử dụng các đặc trưng được tổng hợp từ nhiều reads tại từng vị trí.
- Khai thác thông tin nucleotide, chất lượng và bằng chứng alignment.
- Phát hiện các vị trí ứng viên có khả năng chứa biến thể.
- Có chi phí tính toán tương đối thấp.

**2. Full-Alignment Model**

- Phân tích thông tin alignment chi tiết của các reads.
- Khai thác ngữ cảnh trình tự và thông tin liên quan đến haplotype.
- Hỗ trợ cải thiện dự đoán tại các vị trí khó.
- Yêu cầu nhiều tài nguyên tính toán hơn so với Pileup Model.

Hai thành phần được kết hợp trong pipeline nhằm cân bằng giữa độ chính xác và hiệu quả xử lý.

### 3.3. Hàm mất mát (Loss Function)

Quá trình fine-tuning sử dụng mục tiêu huấn luyện gốc của Clair3, trong đó có các tác vụ phân loại dựa trên Focal Loss.

Công thức tổng quát của Focal Loss:

\[
FL(p_t)=-\alpha_t(1-p_t)^\gamma\log(p_t)
\]

Trong đó:

- \(p_t\): Xác suất mô hình dự đoán cho lớp đúng.
- \(\alpha_t\): Hệ số cân bằng giữa các lớp.
- \(\gamma\): Tham số điều chỉnh mức độ tập trung vào các mẫu khó.

Focal Loss giúp giảm ảnh hưởng của những mẫu dễ và tập trung quá trình học vào các mẫu khó phân loại.

### 3.4. Điểm khác biệt so với Baseline

Trong dự án, mô hình được cải thiện bằng phương pháp **fine-tuning nhánh Pileup** thay vì xây dựng một kiến trúc hoàn toàn mới.

| Thành phần | Baseline | E1 và E2 |
|---|---|---|
| Kiến trúc | Clair3 pretrained | Clair3 pretrained |
| Pileup Model | Weights gốc | Weights sau fine-tuning |
| Full-Alignment Model | Pretrained | Giữ nguyên pretrained |
| Hàm loss | Focal Loss | Focal Loss |
| Learning rate | Không fine-tuning | 1e-4 hoặc 1e-5 |
| Dữ liệu đánh giá | HG003 chr20 test | Cùng tập test |

Dự án không đề xuất kiến trúc mạng hoặc hàm loss mới. Thành phần được nghiên cứu là quá trình fine-tuning và ảnh hưởng của learning rate đối với hiệu quả phát hiện biến thể.

## 4. Thiết lập môi trường và thí nghiệm

### 4.1. Môi trường thực thi

- Nền tảng: Google Colab Free.
- GPU: NVIDIA T4 khi được Colab cấp phát.
- Clair3: phiên bản 2.0.2.
- Công cụ đánh giá: hap.py.
- Công cụ so sánh biến thể: RTG Tools vcfeval.
- Công cụ xử lý dữ liệu: samtools, bcftools.
- Google Drive: lưu dữ liệu, checkpoint, log và kết quả.

Clair3 và hap.py được cài đặt trong hai môi trường riêng để tránh xung đột thư viện.

### 4.2. Cấu hình thí nghiệm

Ba cấu hình được sử dụng:

| Thí nghiệm | Learning rate | Số epoch | Mô tả |
|---|---|---|---|
| Baseline | Không áp dụng | 0 | Clair3 pretrained |
| E1 | 1e-4 | 3 | Fine-tuning Pileup |
| E2 | 1e-5 | 3 | Fine-tuning Pileup |

Các tham số fine-tuning:

- Batch size: 20.
- Chunk size: 5.
- Random seed: 42.
- Platform: ONT.
- Số epoch: 3 cho mỗi thí nghiệm.

E1 và E2 sử dụng cùng checkpoint pretrained ban đầu và cùng cách phân chia dữ liệu để bảo đảm tính nhất quán khi so sánh.

### 4.3. Checkpoint và khả năng tiếp tục huấn luyện

Sau mỗi epoch, weights của mô hình được lưu thành checkpoint trên Google Drive.

Khi phiên Colab bị ngắt kết nối, quá trình huấn luyện có thể tiếp tục từ checkpoint của epoch đã hoàn thành gần nhất.

Cơ chế này có một hạn chế: optimizer state không được khôi phục giữa các lần huấn luyện theo epoch. Vì vậy, đây là hình thức tiếp tục từ model weights, không phải khôi phục chính xác toàn bộ trạng thái huấn luyện.

## 5. Phương pháp đánh giá

Để đánh giá khả năng phát hiện SNP và Indel, dự án sử dụng **hap.py** kết hợp với bộ dữ liệu chuẩn GIAB HG003 v4.2.1.

Công cụ hap.py sử dụng RTG vcfeval để so sánh các biến thể được dự đoán với các biến thể chuẩn, có xét đến sự khác biệt trong cách biểu diễn biến thể.

Các chỉ số đánh giá bao gồm:

### 5.1. Precision

\[
Precision=\frac{TP}{TP+FP}
\]

Precision biểu thị tỷ lệ biến thể dự đoán đúng trong tổng số biến thể được mô hình dự đoán.

### 5.2. Recall

\[
Recall=\frac{TP}{TP+FN}
\]

Recall biểu thị tỷ lệ biến thể thực tế được mô hình phát hiện thành công.

### 5.3. F1-score

\[
F1=\frac{2\times Precision\times Recall}{Precision+Recall}
\]

F1-score là trung bình điều hòa của Precision và Recall, giúp đánh giá cân bằng giữa khả năng phát hiện biến thể và hạn chế dự đoán sai.

Các chỉ số được tính riêng cho SNP và Indel trên cùng vùng test thuộc GIAB confident regions.

## 6. Kết quả thực nghiệm

### 6.1. So sánh F1-score

| Mô hình | SNP F1 | Indel F1 |
|---|---:|---:|
| Baseline | 0.996825 | 0.731707 |
| E1 (LR = 1e-4) | 0.996825 | 0.731707 |
| E2 (LR = 1e-5) | 0.996825 | 0.731707 |

### 6.2. Phân tích kết quả

**Đối với SNP:**

Cả ba mô hình đều đạt F1-score khoảng 0.9968, cho thấy khả năng phát hiện SNP rất cao trên vùng test được lựa chọn.

Việc fine-tuning chưa tạo ra cải thiện về chỉ số F1 so với mô hình pretrained.

**Đối với Indel:**

F1-score của cả ba mô hình đạt khoảng 0.7317, thấp hơn đáng kể so với SNP.

Điều này cho thấy Indel vẫn là loại biến thể khó phát hiện hơn trong thực nghiệm.

**Đối với E1:**

Learning rate 1e-4 giúp training loss giảm mạnh. Tuy nhiên, validation loss tăng trong quá trình huấn luyện, cho thấy dấu hiệu có thể xảy ra overfitting.

**Đối với E2:**

Learning rate 1e-5 giúp training loss giảm chậm hơn, đồng thời validation loss ổn định hơn so với E1.

Tuy nhiên, hiệu quả phát hiện SNP/Indel trên tập test vẫn không thay đổi.

### 6.3. Nhận xét chung

Kết quả cho thấy fine-tuning không phải lúc nào cũng cải thiện hiệu quả dự đoán, đặc biệt khi dữ liệu huấn luyện có kích thước nhỏ.

Một số giả thuyết cần xem xét:

- Mô hình pretrained đã có độ chính xác SNP rất cao trên tập test.
- Lượng dữ liệu fine-tuning chưa đủ lớn.
- Quá trình fine-tuning chỉ tác động đến nhánh Pileup.
- Nhánh Full-Alignment vẫn sử dụng weights pretrained.
- Thay đổi trong xác suất dự đoán chưa đủ để làm thay đổi kết quả variant calling cuối cùng.

F1-score giống nhau không nhất thiết có nghĩa các file VCF dự đoán hoàn toàn giống nhau.

## 7. Hướng dẫn cài đặt và chạy trên WSL2/Docker

### 7.1. Yêu cầu hệ thống

- Windows 10/11 hỗ trợ WSL2.
- Ubuntu chạy trong WSL2.
- Docker Desktop với WSL2 integration đã được bật.
- Git, curl và Python 3.
- Các thư viện Python: pandas, matplotlib.
- Có kết nối Internet để tải dữ liệu và Docker images.

### 7.2. Tạo thư mục dự án

Mở terminal Ubuntu WSL2:

```bash
cd ~
mkdir -p clair3_reproduce
cd ~/clair3_reproduce
mkdir -p data results logs scripts
```

Nếu tải project từ GitHub:

```bash
cd ~
git clone https://github.com/nguyenthanhanton/clair3-hg003-variant-calling.git
cd clair3-hg003-variant-calling
```

Các script hiện tại sử dụng đường dẫn `~/clair3_reproduce`, do đó khi clone cần đổi tên thư mục thành `clair3_reproduce` hoặc điều chỉnh biến `BASE` trong các script.

### 7.3. Tải dữ liệu ONT HG003 chr20

```bash
bash scripts/download_data.sh
```

Dữ liệu sẽ được lưu tại `data/`, bao gồm BAM, BAM index, reference FASTA, GIAB truth VCF và confident BED.

### 7.4. Chạy bốn thí nghiệm Clair3

```bash
bash scripts/run_experiments.sh
```

| Thí nghiệm | Cấu hình |
|---|---|
| E0 | Pileup-only |
| E1 | Clair3 mặc định |
| E2 | Tăng `--var_pct_full=0.9` |
| E3 | Giảm `--indel_min_af=0.10` |

Kết quả dự đoán được lưu tại:

```text
results/
├── E0_pileup/
├── E1_default/
├── E2_full90/
└── E3_indel10/
```

### 7.5. Đánh giá bằng hap.py

```bash
bash scripts/evaluate.sh
```

Script sử dụng GIAB HG003 truth VCF, confident BED và RTG vcfeval để đánh giá SNP/Indel.

### 7.6. Tổng hợp kết quả

```bash
python3 -m pip install pandas matplotlib
python3 scripts/summarize.py
python3 scripts/plot_results.py
```

Nếu Ubuntu không cho phép cài thư viện vào Python hệ thống, hãy tạo virtual environment rồi cài các thư viện bên trong.

Các kết quả tổng hợp gồm:

```text
results/comparison.csv
results/f1_comparison.png
results/runtime_comparison.png
```

### 7.7. Log thực nghiệm

Thời gian chạy và log chi tiết được lưu trong `logs/`.

```bash
cat logs/E0_time.txt
cat logs/E1_time.txt
cat logs/E2_time.txt
cat logs/E3_time.txt
```

Thư mục log không chứa sẵn các log thực thi khi clone repository; chúng được tạo khi chạy các script.

### 7.8. Phạm vi thực nghiệm

Repository này khảo sát ảnh hưởng của các cấu hình inference Clair3 đến Precision, Recall, F1-score và thời gian chạy.

Các thí nghiệm E0–E3 không thực hiện fine-tuning trọng số mạng. Phần fine-tuning trên Google Colab là một nhóm thực nghiệm riêng và chỉ được xem là có thể tái lập từ repository nếu mã huấn luyện và cấu hình tương ứng được bổ sung.
## 8. Cấu trúc Repository

```text
Clair3-ONT-HG003/
├── README.md
├── .gitignore
├── notebooks/
│   └── Clair3_HG003_Colab.ipynb
├── configs/
│   └── experiments.json
├── results/
│   ├── metrics.csv
│   ├── comparison_f1.png
│   └── training_loss.png
└── docs/
    └── report.pdf
```

Các file dữ liệu giải trình tự lớn và checkpoint mô hình được lưu bên ngoài GitHub để giảm kích thước repository.

## 9. Ưu điểm, hạn chế và hướng phát triển

### 9.1. Ưu điểm

- Sử dụng mô hình Clair3 đã được huấn luyện trước.
- Có baseline để so sánh với các mô hình fine-tuned.
- Triển khai hai thí nghiệm thay đổi learning rate.
- Có checkpoint để tiếp tục huấn luyện sau khi Colab ngắt kết nối.
- Sử dụng GIAB và hap.py để đánh giá SNP/Indel.
- Lưu log, metric và biểu đồ phục vụ phân tích.
- Có thể thực hiện trên Google Colab Free.

### 9.2. Hạn chế

- Chỉ sử dụng một vùng demo nhỏ trên chr20.
- Training và testing sử dụng cùng mẫu HG003 nhưng khác vùng genomic.
- Chưa chứng minh khả năng tổng quát hóa sang các mẫu khác.
- Chỉ fine-tuning nhánh Pileup.
- Chưa thay đổi kiến trúc mô hình hoặc hàm loss.
- Optimizer state không được khôi phục giữa các epoch.
- Tài nguyên RAM/GPU trên Google Colab Free bị giới hạn.

### 9.3. Hướng phát triển

Trong tương lai, có thể mở rộng nghiên cứu theo các hướng:

- Huấn luyện trên nhiều chromosome và nhiều mẫu GIAB khác nhau.
- Thử nghiệm thêm các learning rate và batch size.
- Fine-tuning cả Pileup và Full-Alignment.
- Phân tích false positives và false negatives theo từng vùng bộ gen.
- Đánh giá riêng Indel theo độ dài và vùng homopolymer.
- So sánh thời gian inference, RAM và GPU giữa các cấu hình.
- Cải thiện cơ chế checkpoint bằng cách lưu optimizer và scheduler state.

## 10. Tài liệu tham khảo

**Clair3 – Công cụ phát hiện biến thể trên dữ liệu long-read**

https://github.com/HKU-BAL/Clair3

**hap.py – Công cụ đánh giá kết quả variant calling**

https://github.com/Illumina/hap.py

**Genome in a Bottle – Bộ dữ liệu chuẩn đánh giá biến thể di truyền**

https://www.nist.gov/programs-projects/genome-bottle
