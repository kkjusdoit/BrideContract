// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";



/**
 * @title BridePrice
 * @dev 用于管理彩礼资金的智能合约，确保公正、透明、降低纠纷风险
 */
contract BridePrice is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant GROOM_ROLE = keccak256("GROOM_ROLE");
    bytes32 public constant BRIDE_ROLE = keccak256("BRIDE_ROLE");
    bytes32 public constant WITNESS_ROLE = keccak256("WITNESS_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // 合约状态
    enum ContractState {
        Created,      // 合约创建
        Funded,       // 资金已充值
        MarriageConfirmed, // 婚姻已确认
        Cancelled,    // 取消（婚前）
        Divorced,     // 离婚
        Completed     // 合约完成（彩礼转移完成）
    }
    
    // 婚姻状态
    enum MarriageStatus {
        NotMarried,   // 未婚
        Married,      // 已婚
        Divorced      // 离婚
    }

    // 合约信息
    address payable public groom;          // 新郎
    address payable public bride;          // 新娘
    address public witness;                // 见证人
    address public oracle;                 // 预言机
    uint256 public bridePrice;             // 彩礼金额
    uint256 public marriageDate;           // 结婚日期
    uint256 public lockPeriod;             // 锁定期（秒）
    uint256 public refundPercentage;       // 离婚退款百分比 (基于1000，比如500代表50%)
    ContractState public state;            // 当前合约状态
    MarriageStatus public marriageStatus;  // 婚姻状态
    
    // 存储记录
    bool public groomConfirmed;
    bool public brideConfirmed;
    bool public witnessConfirmed;
    
    // 事件
    event ContractCreated(address groom, address bride, uint256 bridePrice);
    event FundsDeposited(uint256 amount);
    event MarriageRegistered(uint256 date);
    event FundsReleased(address to, uint256 amount);
    event ContractCancelled();
    event DivorceRegistered(uint256 date);
    
    /**
     * @dev 部署合约
     * @param _groom 新郎地址
     * @param _bride 新娘地址
     * @param _witness 见证人地址
     * @param _oracle 预言机地址
     * @param _bridePrice 彩礼金额
     * @param _lockPeriod 锁定期（秒）
     * @param _refundPercentage 离婚退款百分比
     */
    constructor(
        address payable _groom,
        address payable _bride,
        address _witness,
        address _oracle,
        uint256 _bridePrice,
        uint256 _lockPeriod,
        uint256 _refundPercentage
    ) {
        require(_groom != address(0), "Invalid groom address");
        require(_bride != address(0), "Invalid bride address");
        require(_witness != address(0), "Invalid witness address");
        require(_oracle != address(0), "Invalid oracle address");
        require(_bridePrice > 0, "Bride price must be greater than 0");
        require(_refundPercentage <= 1000, "Refund percentage cannot exceed 100%");
        
        groom = _groom;
        bride = _bride;
        witness = _witness;
        oracle = _oracle;
        bridePrice = _bridePrice;
        lockPeriod = _lockPeriod;
        refundPercentage = _refundPercentage;
        
        state = ContractState.Created;
        marriageStatus = MarriageStatus.NotMarried;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GROOM_ROLE, _groom);
        _grantRole(BRIDE_ROLE, _bride);
        _grantRole(WITNESS_ROLE, _witness);
        _grantRole(ORACLE_ROLE, _oracle);
        
        emit ContractCreated(_groom, _bride, _bridePrice);
    }
    
    /**
     * @dev 新郎存入彩礼资金
     */
    function depositFunds() external payable nonReentrant onlyRole(GROOM_ROLE) {
        require(state == ContractState.Created, "Contract not in created state");
        require(msg.value == bridePrice, "Amount must match bride price");
        
        state = ContractState.Funded;
        emit FundsDeposited(msg.value);
    }
    
    /**
     * @dev 各方确认婚姻
     */
    function confirmMarriage() external {
        require(state == ContractState.Funded, "Contract not funded");
        
        if (msg.sender == groom) {
            groomConfirmed = true;
        } else if (msg.sender == bride) {
            brideConfirmed = true;
        } else if (msg.sender == witness) {
            witnessConfirmed = true;
        } else {
            revert("Unauthorized");
        }
        
        // 如果所有人都确认，注册婚姻
        if (groomConfirmed && brideConfirmed && witnessConfirmed) {
            state = ContractState.MarriageConfirmed;
            marriageStatus = MarriageStatus.Married;
            marriageDate = block.timestamp;
            emit MarriageRegistered(marriageDate);
        }
    }
    
    /**
     * @dev 预言机确认婚姻状态
     * @param _isMarried 是否已婚
     */
    function oracleConfirmMarriage(bool _isMarried) external onlyRole(ORACLE_ROLE) {
        require(state == ContractState.Funded, "Contract not funded");
        
        if (_isMarried) {
            state = ContractState.MarriageConfirmed;
            marriageStatus = MarriageStatus.Married;
            marriageDate = block.timestamp;
            emit MarriageRegistered(marriageDate);
        }
    }
    
    /**
     * @dev 预言机登记离婚
     */
    function oracleRegisterDivorce() external onlyRole(ORACLE_ROLE) {
        // 只检查婚姻状态，不检查合约状态
        require(marriageStatus == MarriageStatus.Married, "Not in married status");
        
        marriageStatus = MarriageStatus.Divorced;
        emit DivorceRegistered(block.timestamp);
        
        if (state == ContractState.MarriageConfirmed) {
            // 计算退款金额
            uint256 timeElapsed = block.timestamp - marriageDate;
            uint256 refundAmount;
            
            if (timeElapsed < lockPeriod) {
                // 在锁定期内离婚，按比例退款
                refundAmount = (bridePrice * refundPercentage) / 1000;
                
                // 退款给新郎
                if (refundAmount > 0) {
                    groom.transfer(refundAmount);
                    emit FundsReleased(groom, refundAmount);
                }
                
                // 剩余资金给新娘
                uint256 remainingAmount = address(this).balance;
                if (remainingAmount > 0) {
                    bride.transfer(remainingAmount);
                    emit FundsReleased(bride, remainingAmount);
                }
            } else {
                // 锁定期后离婚，全部资金给新娘
                uint256 amount = address(this).balance;
                bride.transfer(amount);
                emit FundsReleased(bride, amount);
            }
            
            state = ContractState.Completed;
        }
    }

    function updateMarriageStatus(MarriageStatus _status) external onlyRole(ORACLE_ROLE) {
        // 允许在任何时候更新婚姻状态
        marriageStatus = _status;
        emit MarriageStatusUpdated(_status, block.timestamp);
    }
    
    /**
     * @dev 解锁彩礼资金（锁定期结束后）
     */
    function releaseFunds() external nonReentrant {
        require(state == ContractState.MarriageConfirmed, "Marriage not confirmed");
        require(block.timestamp >= marriageDate + lockPeriod, "Lock period not ended");
        
        // 转移所有资金给新娘
        uint256 amount = address(this).balance;
        bride.transfer(amount);
        
        state = ContractState.Completed;
        emit FundsReleased(bride, amount);
    }
    
    /**
     * @dev 取消合约（婚前）
     */
    function cancelContract() external {
        require(state == ContractState.Created || state == ContractState.Funded, "Cannot cancel after marriage");
        require(msg.sender == groom || msg.sender == bride, "Only couple can cancel");
        
        // 需要双方同意取消
        if (msg.sender == groom) {
            groomConfirmed = true;
        } else if (msg.sender == bride) {
            brideConfirmed = true;
        }
        
        if (groomConfirmed && brideConfirmed) {
            // 如果已存款，退回给新郎
            if (state == ContractState.Funded) {
                uint256 amount = address(this).balance;
                groom.transfer(amount);
                emit FundsReleased(groom, amount);
            }
            
            state = ContractState.Cancelled;
            emit ContractCancelled();
        }
    }
    
    /**
     * @dev 获取合约余额
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取合约状态信息
     */
    function getContractInfo() public view returns (
        address, address, uint256, ContractState, MarriageStatus, uint256, uint256
    ) {
        return (
            groom,
            bride,
            bridePrice,
            state,
            marriageStatus,
            marriageDate,
            address(this).balance
        );
    }
    
    /**
     * @dev 紧急提款（仅限管理员，用于异常情况）
     */
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(state == ContractState.Cancelled || state == ContractState.Completed, "Contract still active");
        
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
    }
}
