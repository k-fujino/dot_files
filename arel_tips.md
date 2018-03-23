# RailsでArel、早見表

### 等号、不等号

```sql
  scope :without_directs, -> { where( arel_table[:sample_kind_id].not_eq(SampleKind.direct) )}

# >
  scope :sample_check_passed, -> do
    pr = GrandsonTbl.arel_table          # joinでつないだ別テーブルのカラム見るとき
    where(pr[:good_quantity].gt(0))
  end

# =
  scope :no_movement_in_sample, -> do
    st = StTbl.arel_table
    where(st[:id].eq(nil))
  end

# >=
  scope :sons_created_n_month_before, -> (n)do
    sn = SonTbl.arel_table
    where(sn[:created_at].gteq((Time.now - n.months).to_s(:db)))
  end

# <
  scope :after_reflection, -> do
    sn = SonTbl.arel_table
    where(sn[:reflected_at].lt(Time.now.to_s(:db)))
  end

```


### 結合した子テーブルのデータを見る
1. 重複する名前の列は tableにエイリアスをつけておく 
2. selectメソッドで指定。  
3. 補足(結合、抽出条件つき)
 
例) 以下のSQLをArelで

```sql
SELECT A.code, A.id, B.sku_id, B.quantity,B.created_at, B.reflected_at
FROM A_tbls A
INNER JOIN son_tbls B on B.po_id = A.id
INNER JOIN grandson_tbls C on C.po_detail_id = B.id
LEFT JOIN st_tbls st on st.st_tbl_type = 'SonTbl'
  AND st_tbl_id = B.id
  AND st_tbl_kind_id = 5
WHERE B.created_at >= '2017-10-01'
  AND B.reflected_at < now()
  AND B.status = 'recorded'
  AND A.arrival_kind_id <> 5
  AND C.good_quantity > 0
  AND st.id is null;

```

1. 重複する名前の列は tableにエイリアスをつけておく( AS )

```ruby
  sp = Supplier.arel_table.alias('sp')
```

2. selectメソッドで指定。

```ruby
   self.・・・・.select("A_tbls.id as a_id, A_tbls.*, son_tbls.*")
```

3. 外部結合、抽出条件つき

```ruby
  scope :with_st_tbl_sample, -> do
    st = StTbl.arel_table
    pd = SonTbl.arel_table
    arel_table.join(st, Arel::Nodes::OuterJoin).on(
      Arel::Nodes::And.new([
        st[:st_tbl_type].eq('SonTbl'),
        st[:st_tbl_id].eq(pd[:id]),
        st[:st_tbl_kind_id].eq(5)
      ])
    )
  end
```

 生成されるSQLを確かめる(.to_sql)

```ruby
[1] pry(main)> ATbl.with_st_tbl_sample.to_sql
=> "SELECT FROM `A_tbls` LEFT OUTER JOIN `st_tbls` ON `st_tbls`.`st_tbl_type` = 'SonTbl' AND `st_tbls`.`st_tbl_id` = `son_tbls`.`id` AND `st_tbls`.`st_tbl_kind_id = 5"
```

OK

 scopeがつなげれるか確認しておく(.class)

```ruby
[5] pry(main)> PoTbl.with_st_tbl_sample.class
=> Arel::SelectManager
```

  これはそのままではメソッドチェーンでつながらないので

```ruby
  .joins( self.with_st_tbl_sample.join_sources )
```
これでつながる。



### 多段ネスト(子テーブル、孫テーブル)

```ruby
  scope :join_sons_and_grandsons, -> { joins(:son_tbls => [:grandson_tbls]) }
```

