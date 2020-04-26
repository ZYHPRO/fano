{*!
 * Fano Web Framework (https://fanoframework.github.io)
 *
 * @link      https://github.com/fanoframework/fano
 * @copyright Copyright (c) 2018 Zamrony P. Juhara
 * @license   https://github.com/fanoframework/fano/blob/master/LICENSE (MIT)
 *}
unit CoreAppImpl;

interface

{$MODE OBJFPC}

uses

    RunnableIntf,
    DependencyContainerIntf,
    AppIntf,
    AppServiceProviderIntf,
    DispatcherIntf,
    EnvironmentIntf,
    EnvironmentEnumeratorIntf,
    ErrorHandlerIntf,
    StdInIntf,
    RouterIntf,
    RouteBuilderIntf,
    CoreAppConsts;

type

    (*!-----------------------------------------------
     * Base abstract class that implements IWebApplication
     *
     * @author Zamrony P. Juhara <zamronypj@yahoo.com>
     *-----------------------------------------------*)
    TCoreWebApplication = class abstract (TInterfacedObject, IWebApplication, IRunnable)
    protected
        fAppSvc : IAppServiceProvider;
        fRouteBuilder : IRouteBuilder;

        (*!-----------------------------------------------
         * execute application and write response
         *------------------------------------------------
         * @return current application instance
         *-----------------------------------------------
         * TODO: need to think about how to execute when
         * application is run as daemon.
         *-----------------------------------------------*)
        function execute(const env : ICGIEnvironment) : IRunnable;

        procedure reset();

        (*!-----------------------------------------------
         * initialize application dependencies
         *------------------------------------------------
         * @param container dependency container
         * @return true if application dependency succesfully
         * constructed
         *-----------------------------------------------*)
        function initialize(const container : IDependencyContainer) : boolean; virtual;
    public

        (*!-----------------------------------------------
         * constructor
         *------------------------------------------------
         * @param appSvc class provide essentials service
         * @param routeBuilder class responsible to build application routes
         *-----------------------------------------------*)
        constructor create(
            const appSvc : IAppServiceProvider;
            const routeBuilder : IRouteBuilder
        );
        destructor destroy(); override;
        function run() : IRunnable; virtual; abstract;
    end;

implementation

uses

    SysUtils,
    ResponseIntf;

    procedure TCoreWebApplication.reset();
    begin
        fAppSvc := nil;
        fRouteBuilder := nil;
    end;

    (*!-----------------------------------------------
     * constructor
     *------------------------------------------------
     * @param appSvc class that provide essentials services
     * @param routeBuilder class responsible to build application routes
     *-----------------------------------------------*)
    constructor TCoreWebApplication.create(
        const appSvc : IAppServiceProvider;
        const routeBuilder : IRouteBuilder
    );
    begin
        inherited create();
        randomize();
        reset();
        fAppSvc := appSvc;
        fRouteBuilder := routeBuilder;
    end;

    (*!-----------------------------------------------
     * destructor
     *-----------------------------------------------*)
    destructor TCoreWebApplication.destroy();
    begin
        reset();
        inherited destroy();
    end;

    (*!-----------------------------------------------
     * initialize application dependencies
     *------------------------------------------------
     * @param container dependency container
     * @return true if application dependency succesfully
     * constructed
     *-----------------------------------------------*)
    function TCoreWebApplication.initialize(const container : IDependencyContainer) : boolean;
    begin
        try
            fAppSvc.register(container);
            fRouteBuilder.buildRoutes(container, fAppSvc.router);
            result := true;
        except
            on e : Exception do
            begin
                result := false;
                //TODO : improve exception handling
                writeln('Fail to initialize application.');
                writeln('Exception: ', e.ClassName);
                writeln('Message: ', e.Message);
            end;
        end;
    end;

    (*!-----------------------------------------------
     * execute application and write response
     *------------------------------------------------
     * @return current application instance
     *-----------------------------------------------*)
    function TCoreWebApplication.execute(const env : ICGIEnvironment) : IRunnable;
    var response : IResponse;
    begin
        response := fAppSvc.dispatcher.dispatchRequest(env, fAppSvc.stdIn);
        try
            response.write();
            result := self;
        finally
            response := nil;
        end;
    end;

end.
{*!
 * Fano Web Framework (https://fanoframework.github.io)
 *
 * @link      https://github.com/fanoframework/fano
 * @copyright Copyright (c) 2018 Zamrony P. Juhara
 * @license   https://github.com/fanoframework/fano/blob/master/LICENSE (MIT)
 *}
unit CoreAppImpl;

interface

{$MODE OBJFPC}

uses

    RunnableIntf,
    DependencyContainerIntf,
    AppIntf,
    AppServiceProviderIntf,
    DispatcherIntf,
    EnvironmentIntf,
    EnvironmentEnumeratorIntf,
    ErrorHandlerIntf,
    StdInIntf,
    RouterIntf,
    RouteBuilderIntf,
    CoreAppConsts;

type

    (*!-----------------------------------------------
     * Base abstract class that implements IWebApplication
     *
     * @author Zamrony P. Juhara <zamronypj@yahoo.com>
     *-----------------------------------------------*)
    TCoreWebApplication = class abstract (TInterfacedObject, IWebApplication, IRunnable)
    protected
        fAppSvc : IAppServiceProvider;
        fRouteBuilder : IRouteBuilder;

        (*!-----------------------------------------------
         * execute application and write response
         *------------------------------------------------
         * @return current application instance
         *-----------------------------------------------
         * TODO: need to think about how to execute when
         * application is run as daemon.
         *-----------------------------------------------*)
        function execute(const env : ICGIEnvironment) : IRunnable;

        (*!-----------------------------------------------
         * execute application and handle exception
         *------------------------------------------------
         * @param container dependency container
         * @param env CGI environment
         * @return current application instance
         *-----------------------------------------------*)
        function execAndHandleExcept(
            const container : IDependencyContainer;
            const env : ICGIEnvironment;
            const errorHandler : IErrorHandler
        ) : IRunnable;

        (*!-----------------------------------------------
         * execute application
         *------------------------------------------------
         * @param container dependency container
         * @param env CGI environment
         * @return current application instance
         *-----------------------------------------------*)
        function doExecute(
            const container : IDependencyContainer;
            const env : ICGIEnvironment
        ) : IRunnable; virtual; abstract;


        procedure reset();

        (*!-----------------------------------------------
         * initialize application dependencies
         *------------------------------------------------
         * @param container dependency container
         * @return true if application dependency succesfully
         * constructed
         *-----------------------------------------------*)
        function initialize(const container : IDependencyContainer) : boolean; virtual;
    public

        (*!-----------------------------------------------
         * constructor
         *------------------------------------------------
         * @param appSvc class provide essentials service
         * @param routeBuilder class responsible to build application routes
         *-----------------------------------------------*)
        constructor create(
            const appSvc : IAppServiceProvider;
            const routeBuilder : IRouteBuilder
        );
        destructor destroy(); override;
        function run() : IRunnable; virtual; abstract;
    end;

implementation

uses

    SysUtils,
    ResponseIntf,

    //exception-related units
    ERouteHandlerNotFoundImpl,
    EMethodNotAllowedImpl,
    EInvalidMethodImpl,
    EInvalidRequestImpl,
    ENotFoundImpl,
    EDependencyNotFoundImpl,
    EUnauthorizedImpl,
    EForbiddenImpl;

    procedure TCoreWebApplication.reset();
    begin
        fAppSvc := nil;
        fRouteBuilder := nil;
    end;

    (*!-----------------------------------------------
     * constructor
     *------------------------------------------------
     * @param appSvc class that provide essentials services
     * @param routeBuilder class responsible to build application routes
     *-----------------------------------------------*)
    constructor TCoreWebApplication.create(
        const appSvc : IAppServiceProvider;
        const routeBuilder : IRouteBuilder
    );
    begin
        inherited create();
        randomize();
        reset();
        fAppSvc := appSvc;
        fRouteBuilder := routeBuilder;
    end;

    (*!-----------------------------------------------
     * destructor
     *-----------------------------------------------*)
    destructor TCoreWebApplication.destroy();
    begin
        reset();
        inherited destroy();
    end;

    (*!-----------------------------------------------
     * initialize application dependencies
     *------------------------------------------------
     * @param container dependency container
     * @return true if application dependency succesfully
     * constructed
     *-----------------------------------------------*)
    function TCoreWebApplication.initialize(const container : IDependencyContainer) : boolean;
    begin
        try
            fAppSvc.register(container);
            fRouteBuilder.buildRoutes(container, fAppSvc.router);
            result := true;
        except
            on e : Exception do
            begin
                result := false;
                //TODO : improve exception handling
                writeln('Fail to initialize application.');
                writeln('Exception: ', e.ClassName);
                writeln('Message: ', e.Message);
            end;
        end;
    end;

    (*!-----------------------------------------------
     * execute application and write response
     *------------------------------------------------
     * @return current application instance
     *-----------------------------------------------*)
    function TCoreWebApplication.execute(const env : ICGIEnvironment) : IRunnable;
    var response : IResponse;
    begin
        response := fAppSvc.dispatcher.dispatchRequest(env, fAppSvc.stdIn);
        try
            response.write();
            result := self;
        finally
            response := nil;
        end;
    end;

    (*!-----------------------------------------------
     * execute application and handle exception
     *------------------------------------------------
     * @return current application instance
     *-----------------------------------------------*)
    function TCoreWebApplication.execAndHandleExcept(
        const container : IDependencyContainer;
        const env : ICGIEnvironment;
        const errorHandler : IErrorHandler
    ) : IRunnable;
    begin
        try
            result := doExecute(container, env);
        except
            on e : EInvalidRequest do
            begin
                errorHandler.handleError(env.enumerator, e, 400, sHttp400Message);
                reset();
            end;

            on e : EUnauthorized do
            begin
                errorHandler.handleError(env.enumerator, e, 401, sHttp401Message);
                reset();
            end;

            on e : EForbidden do
            begin
                errorHandler.handleError(env.enumerator, e, 403, sHttp403Message);
                reset();
            end;

            on e : ERouteHandlerNotFound do
            begin
                errorHandler.handleError(env.enumerator, e, 404, sHttp404Message);
                reset();
            end;

            on e : ENotFound do
            begin
                errorHandler.handleError(env.enumerator, e, 404, sHttp404Message);
                reset();
            end;

            on e : EMethodNotAllowed do
            begin
                errorHandler.handleError(env.enumerator, e, 405, sHttp405Message);
                reset();
            end;

            on e : EInvalidMethod do
            begin
                errorHandler.handleError(env.enumerator, e, 501, sHttp501Message);
                reset();
            end;

            on e : Exception do
            begin
                errorHandler.handleError(env.enumerator, e);
                reset();
            end;
        end;
    end;

end.
