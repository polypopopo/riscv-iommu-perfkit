以下是针对RISC-V IOMMU HPM/Nested测试方案的构建要求和交付内容的具体说明，结合数据中心场景需求：

---

### **一、构建要求**
#### **1. 硬件/仿真环境**
| **组件**              | **要求**                                                                 |
|-----------------------|-------------------------------------------------------------------------|
| **QEMU**              | ≥7.2.0，需启用RISC-V IOMMU和AIA扩展：<br>`./configure --target-list=riscv64-softmmu --enable-kvm --enable-slirp` |
| **仿真平台**          | QEMU参数需包含：<br>`-M virt,aia=aplic-imsic -cpu rv64,smaia=true,ssaia=true` |
| **宿主系统**          | x86_64 Ubuntu 22.04+，需安装交叉编译工具链（riscv64-linux-gnu-）           |

#### **2. 软件依赖**
```bash
# 宿主系统依赖
sudo apt install -y gcc-riscv64-linux-gnu debootstrap qemu-system-riscv64 \
     libssl-dev device-tree-compiler python3-pip flex bison bc \
     linux-tools-common libelf-dev libdw-dev zlib1g-dev

# 目标系统（RISC-V RootFS）依赖
chroot $ROOTFS apt install -y linux-perf stress-ng iommu-tools
```

#### **3. 内核配置**
必须启用的关键选项：
```text
CONFIG_RISCV_IOMMU=y
CONFIG_RISCV_IOMMU_HPM=y      # HPM支持
CONFIG_IOMMUFD=y              # 嵌套IOMMU依赖
CONFIG_PERF_EVENTS=y
CONFIG_DEBUG_FS=y             # 性能数据导出
```

---

### **二、交付的HPM测试代码**
#### **1. 核心测试模块**
需交付的代码结构：
```text
riscv-iommu-hpm-tests/
├── perf_events/               # HPM性能事件测试
│   ├── iommu_counting.c       # 计数模式测试（如IOMMU请求数）
│   └── iommu_sampling.c       # 采样模式测试（如TLB缺失追踪）
├── nested/                    # 嵌套IOMMU功能测试
│   ├── stage1_flush_test.c    # g-stage无效化验证
│   └── nested_xlate_bench.c   # 两阶段转换延迟测试
└── utils/
    ├── iommu_pmu_helper.h     # PMU寄存器操作封装
    └── dma_mock.c             # 模拟设备DMA请求
```

#### **2. 关键代码示例（HPM计数测试）**
```c
// iommu_counting.c
#include "iommu_pmu_helper.h"

#define IOMMU_PMU_EVENT 0x02  // iommu_requests事件编码

int main() {
    struct iommu_pmu_config cfg = {
        .event_id = IOMMU_PMU_EVENT,
        .filter_pasid = 0x1,   // 监控特定PASID
        .mode = COUNTING_MODE
    };

    // 初始化PMU
    iommu_pmu_init(&cfg);

    // 触发DMA操作
    system("dd if=/dev/zero of=/dev/dma_device bs=1M count=1000");

    // 读取计数器
    uint64_t count = iommu_pmu_read_counter();
    printf("IOMMU requests: %lu\n", count);

    return 0;
}
```

#### **3. 测试脚本**
需交付的自动化脚本：
```bash
#!/bin/bash
# run_hpm_tests.sh

# 1. 启动QEMU
qemu-system-riscv64 -kernel $LINUX/arch/riscv/boot/Image \
  -drive file=$ROOTFS/ubuntu-riscv.img,format=raw \
  -append "root=/dev/vda iommu.pmu=on" &

# 2. 执行测试
ssh root@localhost -p 2222 <<EOF
  cd /root/riscv-iommu-hpm-tests
  make && ./run_all_tests.sh
  perf stat -e riscv_iommu/iommu_requests/ -a sleep 5
EOF

# 3. 生成报告
python3 generate_report.py --input test_logs/ --output hpm_report.html
```

---

### **三、交付文档要求**
#### **1. 测试设计文档**
需包含：
- **HPM事件列表**：对应`/sys/bus/event_source/devices/riscv_iommu/events`的详细说明
- **测试场景矩阵**：
  | **测试类型**   | **触发条件**              | **预期结果**                  |
  |---------------|--------------------------|-----------------------------|
  | 计数模式       | 持续DMA压力              | 计数器线性增长                |
  | 采样模式       | 随机GPA-HPA映射变更       | 捕获TLB失效事件               |

#### **2. 性能分析报告模板**
```markdown
## RISC-V IOMMU HPM测试报告
### 测试环境
- QEMU版本: 7.2.0
- 内核补丁: [Zong Li HPM v2](https://lore.kernel.org/all/20240614142156.29420-2-zong.li@sifive.com/)

### 关键指标
| 测试项         | 数值       | 对比参考(x86 VT-d) |
|----------------|-----------|-------------------|
| IOMMU请求延迟   | 152ns     | 89ns              |
| TLB命中率       | 98.2%     | 99.5%             |

### 问题发现
1. PASID缓存冲突率较高（12%），建议优化缓存替换算法
2. 嵌套翻译延迟标准差达±15ns，存在抖动
```

#### **3. 构建指南**
需明确：
```text
1. 内核编译步骤：
   make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- \
    CONFIG_RISCV_IOMMU_HPM=y

2. Perf工具交叉编译：
   cd $LINUX/tools/perf && make \
    ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- \
    NO_LIBBPF=1
```

---

### **四、扩展要求（Nested IOMMU）**
#### **1. 测试重点**
- **地址转换正确性**：GVA→GPA→HPA的级联映射验证
- **TLB一致性**：修改stage-1页表后的`iotlb_sync_map`调用验证
- **异常传递**：客户机IO页错误是否正确触发宿主ECALL

#### **2. 参考测试用例**
```c
// nested_xlate_bench.c
void test_nested_latency() {
    start_timer();
    // 触发嵌套转换
    device_dma(gva);
    uint64_t latency = stop_timer();
    
    assert(latency < 500); // 阈值根据硬件调整
    log("Nested translate latency: %luns", latency);
}
```

---

### **五、验证方法**
1. **单元测试**：通过QEMU的`-d guest_errors`捕获地址转换错误
2. **性能验证**：使用`perf stat`对比启用/禁用HPM的开销
3. **压力测试**：`stress-ng --vm-bytes 4G`下持续运行24小时

该方案可直接集成到openEuler的CI/CD流程，建议配合[LKP](https://github.com/intel/lkp-tests)进行自动化性能回归测试。 
