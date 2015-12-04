fs           = require 'fs'
vm           = require 'vm'
path         = require 'path'
CoffeeScript = require 'coffee-script'

class CloudFormationTemplateContext
  constructor: ->
    @_resources   = {}
    @_parameters  = {}
    @_mappings    = null
    @_outputs     = {}
    @_description = null
    @_conditions  = null
    @Params       = {}
    @Resources    = {}
    @Mappings     = {}
    @Conditions   = {}
    @AWS =
      AutoScaling:
        AutoScalingGroup: null
        LaunchConfiguration: null
        ScalingPolicy: null
        LifecycleHook: null
        ScheduledAction: null
        Trigger: null
      CloudFormation:
        Authentication: null
        CustomResource: null
        Stack: null
        WaitCondition: null
        WaitConditionHandle: null
      CloudFront:
        Distribution: null
      CloudWatch:
        Alarm: null
      CodeDeploy:
        Application: null
        DeploymentConfig: null
        DeploymentGroup: null
      CodePipeline:
        Pipeline: null
        CustomActionType: null
      Config:
        ConfigRule: null
        ConfigurationRecorder: null
        DeliveryChannel: null
      DirectoryService:
        SimpleAD: null
      CloudTrail:
        Trail: null
      DataPipeline:
        Pipeline: null
      DynamoDB:
        Table: null
      EC2:
        CustomerGateway: null
        DHCPOptions: null
        EIP: null
        EIPAssociation: null
        Instance: null
        InternetGateway: null
        NetworkAcl: null
        NetworkAclEntry: null
        NetworkInterface: null
        PlacementGroup: null
        Route: null
        RouteTable: null
        SecurityGroup: null
        SecurityGroupIngress: null
        SecurityGroupEgress: null
        Subnet: null
        SubnetNetworkAclAssociation: null
        SubnetRouteTableAssociation: null
        SpotFleet: null
        Volume: null
        VolumeAttachment: null
        VPC: null
        VPCDHCPOptionsAssociation: null
        VPCEndpoint: null
        VPCGatewayAttachment: null
        VPNConnection: null
        VPNGateway: null
      ECS:
        Cluster: null
        Service: null
        TaskDefinition: null
      ElastiCache:
        CacheCluster: null
        ParameterGroup: null
        ReplicationGroup: null
        SecurityGroup: null
        SecurityGroupIngress: null
      ElasticBeanstalk:
        Application: null
        ApplicationVersion: null
        Environment: null
        ConfigurationTemplate: null
      ElasticLoadBalancing:
        LoadBalancer: null
      EFS:
        FileSystem: null
        MountTarget: null
      IAM:
        AccessKey: null
        Group: null
        InstanceProfile: null
        ManagedPolicy: null
        Policy: null
        Role: null
        User: null
        UserToGroupAddition: null
      Kinesis:
        Stream: null
      KMS:
        Key: null
      Logs:
        LogGroup: null
        MetricFilter: null
        SubscriptionFilter: null
      Lambda:
        EventSourceMapping: null
        Function: null
        Permission: null
      OpsWorks:
        App: null
        Instance: null
        Layer: null
        Stack: null
      Redshift:
        Cluster: null
        ClusterParameterGroup: null
        ClusterSecurityGroup: null
        ClusterSubnetGroup: null
      RDS:
        DBCluster: null
        DBClusterParameterGroup: null
        DBInstance: null
        DBParameterGroup: null
        DBSubnetGroup: null
        DBSecurityGroup: null
        DBSecurityGroupIngress: null
        EventSubscription: null
        OptionGroup: null
      Route53:
        RecordSet: null
        RecordSetGroup: null
        HostedZone: null
        HealthCheck: null
      SDB:
        Domain: null
      S3:
        Bucket: null
        BucketPolicy: null
      SNS:
        Topic: null
        TopicPolicy: null
      SQS:
        Queue: null
        QueuePolicy: null
      SSM:
        Document: null
      WorkSpaces:
        Workspace: null
    @Param =
      String: (name, arg1, arg2) =>             @_paramByType 'String', name, arg1, arg2
      Number: (name, arg1, arg2) =>             @_paramByType 'Number', name, arg1, arg2
      CommaDelimitedList: (name, arg1, arg2) => @_paramByType 'CommaDelimitedList', name, arg1, arg2
      AWS: (type, name, arg1, arg2) => @_paramByType "AWS::#{type}", name, arg1, arg2
      AWSList: (type, name, arg1, arg2) => @_paramByType "List<AWS::#{type}>", name, arg1, arg2
    @_buildCall null, null, 'AWS', @AWS

  _paramByType: (type, name, arg1, arg2) =>
    result = {}
    if not arg1?
      result[name] = {}
    else if not arg2?
      result[name] = if typeof arg1 is 'string' then Description: arg1 else arg1
    else
      result[name] = arg2
      result[name].Description = arg1
    result[name].Type = type
    @_set result, @_parameters
    @Params[name] = Ref: name

  _buildCall: (parent, lastKey, awsType, leaf) =>
    if leaf?
      for key, val of leaf
        @_buildCall leaf, key, "#{awsType}::#{key}", val
      return
    parent[lastKey] = (name, props) =>
      @_resourceByType awsType, name, props

  # todo: this cheesy forward decl thing shouldn't be necessary
  DeclareResource: (name) =>
    @Resources[name] ?= Ref: name

  _resourceByType: (type, name, props) =>
    result = {}
    if props?.Metadata? or props?.Properties? or props?.DependsOn? or props?.UpdatePolicy? or props?.CreationPolicy? or props?.Condition?
      result[name] = props
      result[name].Type = type
    else
      result[name] =
        Type: type
        Properties: props
    @_set result, @_resources
    @DeclareResource name

  _set: (source, target) ->
    for key, val of source
      target[key] = val

  Mapping: (name, map) =>
    @_mappings ?= {}
    result = {}
    result[name] = map
    @_set result, @_mappings

  Output: (name, args...) =>
    result = {}
    if args.length is 1
      result[name] =
        Value: args[0]
    if args.length is 2
      result[name] =
        Description: args[0]
        Value: args[1]
    @_set result, @_outputs

  Condition: (name, intrinsicfn) =>
    @_conditions ?= {}
    result = {}
    result[name] = intrinsicfn
    @_set result, @_conditions

  Description: (d) => @_description = d

  Tag: (key, val) ->
    Key: key
    Value: val

  #utility functions
  Join: (delimiter, args...) ->
    if args.length is 1 and (args[0] instanceof Array)
      'Fn::Join': [ delimiter, args[0] ]
    else
      'Fn::Join': [ delimiter, args ]
  FindInMap: (args...) ->
    'Fn::FindInMap': args
  GetAtt: (args...) ->
    'Fn::GetAtt': args
  Base64: (arg) ->
    'Fn::Base64': arg
  GetAZs: (arg) ->
    'Fn::GetAZs': arg
  Select: (index, args...) ->
    if args.length is 1 and (args[0] instanceof Array)
      'Fn::Select': [index, args[0]]
    else
      'Fn::Select': [index, args]
  And: (condition, conditions...) ->
    if conditions.length is 1 and (conditions[0] instanceof Array)
      'Fn::And': [condition, conditions[0]]
    else
      'Fn::And': [condition, conditions]
  Equals: (value_1, value_2) ->
    'Fn::Equals': [ value_1, value_2 ]
  If: (condition, value_if_true, value_if_false) ->
    'Fn::If': [condition, value_if_true, value_if_false]
  Not: (condition) ->
    'Fn::Not': [condition]
  Or: (condition, conditions...) ->
    if conditions.length is 1 and (conditions[0] instanceof Array)
      'Fn::Or': [condition, conditions[0]]
    else
      'Fn::Or': [condition, conditions]
  AccountId: Ref: 'AWS::AccountId'
  NotificationARNs: Ref: 'AWS::NotificationARNs'
  NoValue: Ref: 'AWS::NoValue'
  Region: Ref: 'AWS::Region'
  StackId: Ref: 'AWS::StackId'
  StackName: Ref: 'AWS::StackName'
  InitScript: (arg) ->
    existsSyncFunc = if fs.existsSync? then fs.existsSync else path.existsSync
    if not existsSyncFunc(arg)
      text = arg
    else
      text = fs.readFileSync(arg).toString()
    chunks = []
    #todo: fix this abhoration of regex
    pattern = /((.|\n)*?)%{([^}?]+)}?((.|\n)*)/
    match = text.match pattern
    while match
      chunks.push match[1]
      compiled = CoffeeScript.compile match[3], {bare: true}
      chunks.push eval compiled
      text = match[4]
      match = text.match pattern
    chunks.push text if text and text.length > 0
    @Base64 @Join '', chunks

module.exports.CloudFormationTemplateContext = CloudFormationTemplateContext

module.exports = (func) ->
  context = new CloudFormationTemplateContext
  func.apply context, [context]
  template = AWSTemplateFormatVersion: '2010-09-09'
  template.Description = context._description if context._description?
  template.Parameters  = context._parameters
  template.Mappings    = context._mappings    if context._mappings?
  template.Resources   = context._resources
  template.Outputs     = context._outputs
  template.Conditions  = context._conditions  if context._conditions?
  template

require('pkginfo')(module, 'version')
