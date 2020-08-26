// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.8.0;

/**
这里面有三个合约，分别是：发布者合约Issuer; 身份合约Identity; 恢复合约Recovery;
 */


/************发布者合约***********/
contract Issuer {
    address owner_sp;
    address[] identities;
    Identity identity_c;
    modifier onlyOwner(){
        require(msg.sender == owner_sp);
        _;
    }

    constructor() public{
        owner_sp = msg.sender;
    }
    //增加身份合约
    function addIdentity(address _identity_owner) public onlyOwner{
        
        identity_c = new Identity(address(this), _identity_owner);
        address identity_addr = address(identity_c);
        identities.push(identity_addr);
    }

    function getDetails() public view returns (address _owner_sp, address[] memory _identities){
        _owner_sp = owner_sp;
        _identities = identities;
    }

}

/************身份合约***********/
contract Identity {
    address owner;
    address issuer;

    Recovery recovery;
    string merkle_hash;
    string signed_attr;

    /********修饰函数部分*******/
    // 仅限身份拥有者
    modifier onlyOwner(){
        if (msg.sender == owner)
            _;
    }
    //仅限身份拥有者或恢复合约
    modifier onlyOwnerOrRecovery(){
        if (msg.sender == owner || msg.sender == address(recovery))
            _;
    }

    /********函数部分*******/
    //构造函数
    constructor(address _issuer, address _owner) public {
        owner = _owner;
        issuer = _issuer;
        recovery = new Recovery(address(this));
    }

    //设置恢复函数地址
    function setRecovery(Recovery _recovery) public onlyOwner {
        recovery = _recovery;
    }
    //设置merkle根hash
    function setMerkleHash(string memory _merkle_hash) public onlyOwner{
        merkle_hash = _merkle_hash;
    }

    function setSignedAttr(string memory _signed_attr) public onlyOwner{
        signed_attr =_signed_attr;
    }


    /**
    * 设置好友列表（调用恢复合约进行设置）
    * @param friends 好友地址列表, 格式示例["0x123","0x456"]
    */
    function setFriends(address[] memory friends) public onlyOwner{
        Recovery recovery_c = Recovery(recovery);
        recovery_c.setFriends(friends);
    }
    //改变身份拥有者
    function changeOwner(address _owner) public onlyOwnerOrRecovery{
        owner = _owner;
    }

    /**
    获得身份合约信息
    @return _owner 身份所有者
    @return _merkle_hash 存储的merkle根hash
    @return _recovery 绑定的恢复合约地址
    @return _issuer 发布者合约地址
     */
    function getDetails() public view onlyOwner
        returns (address _owner,  string memory _merkle_hash, Recovery _recovery, address _issuer)
    {
        _owner = owner;
        _merkle_hash = merkle_hash;
        _recovery = recovery;
        _issuer = issuer;
    }
    // 获取Merkle hash（公开函数，任何人都能查询到）
    function getMerkleHash() public view returns (string memory _merkle_hash){
        _merkle_hash = merkle_hash;
    }

}

/**********恢复合约***********/
contract Recovery {
    address uuid;
    address[] friends;
    //恢复账户部分用到数据
    mapping(address => address) recoveries;  //各个好友提交的账户地址
    mapping(address => uint) proposed_keys; //收集到的账户地址的个数
    mapping(address => bool) change_flag; //一个key是否已经被添加进去的flag

    /*******修饰符部分*******/
    //仅限好友
    modifier onlyFriends(){
        for (uint i = 0; i < friends.length; i++)
            if(friends[i] == msg.sender)
                _;
    }
    //仅限绑定的身份进行操作
    modifier onlyUuid(){
        if (msg.sender == uuid)
            _;
    }

    //------函数部分-------
    //构造函数
    constructor(address _uuid) public {
        uuid = _uuid;
    }
    //设置好友列表
    function setFriends(address[] memory _friends) public onlyUuid{
        friends = _friends;
    }
    //获取好友列表
    function getFriends() public view onlyUuid returns (address[] memory _friends){
        _friends = friends;
    }
    // 增加“提案”（找回账户操作）
    function addProposal(address _key) public onlyFriends{
        //如果满足3个条件：
        if (recoveries[msg.sender] != _key
            && proposed_keys[recoveries[msg.sender]] == 0
            && !change_flag[_key]){
            recoveries[msg.sender] = _key;
            proposed_keys[_key] += 1;
        }
        //如果某个key提交的方案数大于好友数的一半,则更改身份合约的拥有者地址为_key（新提交的地址）
        if (proposed_keys[_key] >= (friends.length / 2)){
            Identity identity_c = Identity(uuid);
            proposed_keys[_key] = 0;
            identity_c.changeOwner(_key);
            change_flag[_key] = true;
        }
    }
    // 获取恢复合约状态信息
    function getRecovery(address _key) public view returns(uint _num, uint _total_num){
        _num = proposed_keys[_key];
        _total_num = friends.length / 2;
    }
    
    function getDetails() public view returns (address _uuid, address[] memory _friends) {
        _uuid = uuid;
        _friends = friends;
    }

}