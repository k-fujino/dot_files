# RailsでArel、早見表

### 等号、不等号
```
  scope :without_directs, -> { where( arel_table[:arrival_kind_id].not_eq(ArrivalKind.direct) )}

  scope :warehousing_check_passed, -> do
    pr = PoReceiveTbl.arel_table          # joinでつないだ別テーブルのカラム見るときの指定
    where(pr[:good_quantity].gt(0))
  end

  scope :no_movement_in_warehouse, -> do
    st = StTbl.arel_table
    where(st[:id].eq(nil))
  end

  scope :detail_created_n_month_before, -> (n)do
    pd = PoDetailTbl.arel_table
    where(pd[:created_at].gteq((Time.now - n.months).to_s(:db)))
  end

  scope :after_reflection_and_not_arrived, -> do
    pd = PoDetailTbl.arel_table
    where(pd[:reflected_at].lt(Time.now.to_s(:db)))
  end

```


### 長いSQLを作るとき、-> 短いscopeに分割。
例
```
SELECT po.code, po.id, pd.sku_id, pd.quantity,pd.created_at, pd.reflected_at
FROM po_tbls po
INNER JOIN po_detail_tbls pd on pd.po_id = po.id
INNER JOIN po_receive_tbls pr on pr.po_detail_id = pd.id
LEFT JOIN st_tbls st on st.st_tbl_type = 'PoDetailTbl'
  AND st_tbl_id = pd.id
  AND st_tbl_kind_id = 5
WHERE pd.created_at >= '2017-10-01'
  AND pd.reflected_at < now()
  AND pd.status = 'recorded'
  AND po.arrival_kind_id <> 5
  AND pr.good_quantity > 0
  AND st.id is null;


     self.join_details_and_receives
          .detail_created_n_month_before(3)
          .hoge....
          .joins( self.with_st_tbl_sample.join_sources )
          .select("po_tbls.id as po_id, po_tbls.*, po_details_tbls.*")
```

### 外部結合
```
  scope :with_st_tbl_sample, -> do
    st = StTbl.arel_table
    pd = PoDetailTbl.arel_table
    arel_table.join(st, Arel::Nodes::OuterJoin).on(
      Arel::Nodes::And.new([
        st[:st_tbl_type].eq('PoDetailTbl'),
        st[:st_tbl_id].eq(pd[:id]),
        st[:st_tbl_kind_id].eq(5)
      ])
    )
  end
```
生成されるSQLを確かめる(.to_sql)
```
[1] pry(main)> PoTbl.with_st_tbl_sample.to_sql
=> "SELECT FROM `po_tbls` LEFT OUTER JOIN `st_tbls` ON `st_tbls`.`st_tbl_type` = 'PoDetailTbl' AND `st_tbls`.`st_tbl_id` = `po_detail_tbls`.`id` AND `st_tbls`.`st_tbl_
```
OK

scopeがつなげれるか確認しておく(.class)
```
[5] pry(main)> PoTbl.with_st_tbl_sample.class
=> Arel::SelectManager
```
これはそのままではメソッドチェーンでつながらないので
```
  .joins( self.with_st_tbl_sample.join_sources )
```
...これでつながる。(scopeの中に書いたほうがいいかも)



### INNER JOINの多段ネスト
```
  scope :join_details_and_receives, -> { joins(:po_detail_tbls => [:po_receive_tbls]) }
```
