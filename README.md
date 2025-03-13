您可以在Remix中模拟这个彩礼智能合约的完整使用流程。以下是一个逐步指南：

## 在Remix中部署和测试合约的步骤

### 1. 部署合约

1. 在Remix中，点击"Deploy & Run Transactions"选项卡
2. 从账户列表中选择一个账户作为部署者（将成为管理员）
3. 在部署参数中填入以下信息：
   - `_groom`: 选择一个账户地址作为新郎
   - `_bride`: 选择另一个账户地址作为新娘
   - `_witness`: 选择第三个账户作为见证人
   - `_oracle`: 选择第四个账户作为预言机
   - `_bridePrice`: 输入彩礼金额（例如：1000000000000000000 Wei，相当于1 ETH）
   - `_lockPeriod`: 输入锁定期（秒），例如：2592000（30天）
   - `_refundPercentage`: 输入退款百分比，例如：500（表示50%）
4. 点击"Deploy"按钮部署合约

### 2. 使用合约模拟结婚流程

#### 步骤1: 新郎存入彩礼
1. 从账户下拉列表中切换到新郎账户
2. 找到`depositFunds`函数
3. 在Value字段输入彩礼金额（与部署时设置的相同）
4. 点击`depositFunds`按钮

#### 步骤2: 确认婚姻
1. 从新郎账户调用`confirmMarriage`函数
2. 切换到新娘账户，调用`confirmMarriage`函数
3. 切换到见证人账户，调用`confirmMarriage`函数
4. 此时，合约状态应该变为`MarriageConfirmed`

#### 步骤3: 检查合约状态
1. 调用`getContractInfo`函数查看当前合约状态
2. 确认`marriageStatus`为`Married`(1)，`state`为`MarriageConfirmed`(2)

### 3. 模拟其他场景

#### 场景A: 正常解锁资金
1. 在Remix中，使用"Increase time"功能模拟时间经过（在Advanced选项中）
2. 增加时间超过锁定期（例如设置为31天）
3. 从任意账户调用`releaseFunds`函数
4. 检查彩礼是否已转移给新娘

#### 场景B: 离婚情况
1. 从预言机账户调用`oracleRegisterDivorce`函数
2. 检查资金分配状态：
   - 如果在锁定期内离婚，新郎应获得部分退款
   - 如果在锁定期后离婚，全部资金应转给新娘

#### 场景C: 婚前取消
1. 在新彩礼合约中，从新郎账户调用`cancelContract`函数
2. 从新娘账户调用`cancelContract`函数
3. 检查资金是否退回给新郎

### 4. 检查合约余额

在任何操作后，您都可以调用`getBalance`函数查看合约当前余额

### 5. 监控事件

在Remix界面底部的"Logs"部分，您可以看到合约触发的各种事件，包括：
- `ContractCreated`
- `FundsDeposited`
- `MarriageRegistered`
- `FundsReleased`
- `ContractCancelled`
- `DivorceRegistered`

## 提示

1. 使用Remix的"At Address"功能可以从不同账户连接到同一个合约实例
2. 使用"Debug"按钮可以跟踪交易执行的详细步骤
3. 经常检查合约余额和状态，确保一切按预期进行
4. 您可以在状态面板中观察变量值的变化

这样，您就可以完整地模拟彩礼合约从创建到各种可能结果的整个生命周期。
