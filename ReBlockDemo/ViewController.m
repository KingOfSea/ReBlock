//
//  ViewController.m
//  BlockAspects
//
//  Created by wangzhihai on 2018/11/9.
//  Copyright © 2018年 WangZhihai. All rights reserved.
//

#import "ViewController.h"
#import "ReBlock.h"
#import "ViewController1.h"
#import "ViewController2.h"

static NSString *kTableViewCellId = @"TableViewCellId";

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSArray *dataArray;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Home";
    
    self.dataArray = @[@"hook self block", @"hook kit block"];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    tableView.delegate = self;
    tableView.dataSource = self;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kTableViewCellId];
    tableView.tableFooterView = [UIView new];
    [self.view addSubview:tableView];
    self.tableView = tableView;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    return [tableView dequeueReusableCellWithIdentifier:kTableViewCellId];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    cell.textLabel.text = _dataArray[indexPath.row];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 60.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        [self.navigationController pushViewController:[ViewController1 new] animated:YES];
        return;
    }
    if (indexPath.row == 1) {
        [self.navigationController pushViewController:[ViewController2 new] animated:YES];
        return;
    }
}

@end
