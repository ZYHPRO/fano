{*!
 * Fano Web Framework (https://fanoframework.github.io)
 *
 * @link      https://github.com/fanoframework/fano
 * @copyright Copyright (c) 2018 Zamrony P. Juhara
 * @license   https://github.com/fanoframework/fano/blob/master/LICENSE (MIT)
 *}

unit RdbmsPoolImpl;

interface

{$MODE OBJFPC}
{$H+}

uses

    RdbmsIntf,
    RdbmsFactoryIntf,
    RdbmsPoolIntf,
    db,
    sqldb,
    InjectableObjectImpl;

type

    TRdbmsList = specialize TFPGInterfacedObjectList<IRdbms>;

    (*!------------------------------------------------
     * basic class having capability to
     * handle database connection pool
     *
     * @author Zamrony P. Juhara <zamronypj@yahoo.com>
     *-------------------------------------------------*)
    TRdbmsPool = class(TInjectableObject, IRdbmsPool)
    private
        fAvailableRdbmsList : TRdbmsList;
        fUsedRdbmsList : TRdbmsList;

        fRdbmsFactory : IRdbmsFactory;
        fPoolSize : integer;
        fHost : string;
        fUser : string;
        fPassword : string;
        fDbName : string;
        fPort : word;

        procedure initPool(const poolSize : integer);
        procedure clearPool();
    public
        constructor create(
            const rdbmsFactory : IRdbmsFactory;
            const poolSize : integer
        );
        destructor destroy(); override;

        (*!------------------------------------------------
         * get rdbms connection from pool
         *-------------------------------------------------
         * @return database connection instance
         *-------------------------------------------------*)
        function acquire() : IRdbms;

        (*!------------------------------------------------
         * release rdbms connection back into pool
         *-------------------------------------------------
         * @return database connection instance
         *-------------------------------------------------*)
        procedure release(const conn : IRdbms);

        (*!------------------------------------------------
         * get total rdbms connection in pool
         *-------------------------------------------------
         * @return number of connection in pool
         *-------------------------------------------------*)
        function count() : integer;

        (*!------------------------------------------------
         * get total available rdbms connection in pool
         *-------------------------------------------------
         * @return number of available connection in pool
         *-------------------------------------------------*)
        function availableCount() : integer;

        (*!------------------------------------------------
         * get total used rdbms connection in pool
         *-------------------------------------------------
         * @return number of used connection in pool
         *-------------------------------------------------*)
        function usedCount() : integer;
    end;

implementation

uses

    SysUtils,
    fgl,
    EPoolConnectionImpl;

resourcestring

    sErrPoolConnNotAvail = 'No available connections to acquire';
    sErrPoolConnNotUsed = 'No used connections to release';

    constructor TRdbmsPool.create(
        const rdbmsFactory : IRdbmsFactory;
        const poolSize : integer;
        const host : string;
        const dbname : string;
        const username : string;
        const password : string;
        const port : word
    );
    begin
        fAvailableRdbmsList := TRdbmsList.create();
        fUsedRdbmsList := TRdbmsList.create();
        fRdbmsFactory := rdbmsFactory;
        fPoolSize := poolSize;
        fHost := host;
        fDbName := dbname;
        fUser := username;
        fPassword := password;
        fPort := port;
        initPool(fPoolSize);
    end;

    destructor TRdbmsPool.destroy();
    begin
        clearPool();
        fAvailableRdbmsList.free();
        fUsedRdbmsList.free();
        fRdbmsFactory := nil;
        inherited destroy();
    end;

    procedure TRdbmsPool.initPool(const poolSize : integer);
    var i : integer;
        conn : IRdbms;
    begin
        fAvailableRdbmsList.capacity := poolSize;
        fUsedRdbmsList.capacity := poolSize;
        for i:= 0 to poolSize - 1 do
        begin
            conn := fRdbmsFactory.build();
            conn.connect(fHost, fDbName, fUser, fPassword, fPort);
            fAvailableRdbmsList.add(conn);
        end;
    end;

    procedure TRdbmsPool.clearPool();
    begin
        fAvailableRdbmsList.clear();
        fUsedRdbmsList.clear();
    end;

    (*!------------------------------------------------
     * get rdbms connection from pool
     *-------------------------------------------------
     * @return database connection instance
     *-------------------------------------------------*)
    function TRdbmsPool.acquire() : IRdbms;
    begin
        if (fAvailableRdbmsList.count = 0) then
        begin
            raise EPoolConnection.create(sErrPoolConnNotAvail);
        end;
        result := fAvailableRdbmsList.last;
        fUsedRdbmsList.add(result);
        fAvailableRdbmsList.remove(result);
    end;

    (*!------------------------------------------------
     * release rdbms connection back into pool
     *-------------------------------------------------
     * @return database connection instance
     *-------------------------------------------------*)
    procedure TRdbmsPool.release(const conn : IRdbms);
    begin
        if (fUsedRdbmsList.count = 0) then
        begin
            raise EPoolConnection.create(sErrPoolConnNotUsed);
        end;
        fUsedRdbmsList.remove(conn);
        fAvailableRdbmsList.add(conn);
    end;

    (*!------------------------------------------------
     * get total rdbms connection in pool
     *-------------------------------------------------
     * @return number of connection in pool
     *-------------------------------------------------*)
    function TRdbmsPool.count() : integer;
    begin
        result := availableCount() + usedCount();
    end;

    (*!------------------------------------------------
     * get total available rdbms connection in pool
     *-------------------------------------------------
     * @return number of available connection in pool
     *-------------------------------------------------*)
    function TRdbmsPool.availableCount() : integer;
    begin
        result := fAvailableRdbmsList.count;
    end;

    (*!------------------------------------------------
     * get total used rdbms connection in pool
     *-------------------------------------------------
     * @return number of used connection in pool
     *-------------------------------------------------*)
    function TRdbmsPool.usedCount() : integer;
    begin
        result := fUsedRdbmsList.count;
    end;
end.
